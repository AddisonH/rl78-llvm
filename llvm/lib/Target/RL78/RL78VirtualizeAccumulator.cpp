//===-- RL78VirtualizeAccumulator.cpp - AX/A spans to virtual registers ---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The custom inserters pin accumulator operands to the physical registers
// $rp0 (AX) and $r1 (A):
//
//   $rp0 = COPY %a
//   $rp0 = ADDW_rp_rp $rp0, %b
//   %c = COPY $rp0
//
// Physical register dependences serialize every such span, so neither the
// scheduler nor the allocator can move them, and the coalescer joins a
// virtual register with $rp0 only in the simplest cases.
//
// Rewrite each span that is local to a block and referenced only through
// explicit operands naming the whole register into a virtual register of the
// single-register class (RL78AXRP or RL78AReg). The allocator still has to put
// it in AX/A, but now knows its live range and can split around it.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78InstrInfo.h"
#include "RL78Subtarget.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetRegisterInfo.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "rl78-virtualize-acc"
using namespace llvm;

STATISTIC(NumSpans, "Number of AX/A spans moved to virtual registers");
STATISTIC(NumKept, "Number of AX/A spans left in the physical register");
STATISTIC(NumWidened, "Number of values widened from AX/A to any register");


static cl::opt<bool> AccCensus("rl78-acc-census", cl::Hidden, cl::init(false));

namespace {
class RL78VirtualizeAccumulator : public MachineFunctionPass {
public:
  static char ID;
  explicit RL78VirtualizeAccumulator(bool WidenOnly = false)
      : MachineFunctionPass(ID), WidenOnly(WidenOnly) {}

  StringRef getPassName() const override {
    return "RL78 allocate AX/A operands as virtual registers";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  // Run right after instruction selection: only widen the copies it made.
  bool WidenOnly;
  // A value in AX or A: its definition and the operands that read it.
  struct Span {
    MachineOperand *Def = nullptr;
    // Each read, with the subregister index it reads (A or X of AX), or 0.
    SmallVector<std::pair<MachineOperand *, unsigned>, 4> Uses;
    bool OK = false;
    // The span whose value this one's definition is tied to, or -1. The two
    // are rewritten together or not at all.
    int TiedFrom = -1;
  };

  MachineRegisterInfo *MRI = nullptr;
  const TargetRegisterInfo *TRI = nullptr;

  bool runOnBlock(MachineBasicBlock &MBB);
  void rewrite(Span &S);
};
} // end anonymous namespace

char RL78VirtualizeAccumulator::ID = 0;

FunctionPass *llvm::createRL78VirtualizeAccumulatorPass(bool WidenOnly) {
  return new RL78VirtualizeAccumulator(WidenOnly);
}

static const TargetRegisterClass *accClass(Register R) {
  if (R == RL78::RP0)
    return &RL78::RL78AXRPRegClass;
  if (R == RL78::R1)
    return &RL78::RL78ARegRegClass;
  return nullptr;
}

void RL78VirtualizeAccumulator::rewrite(Span &S) {
  Register V = MRI->createVirtualRegister(accClass(S.Def->getReg()));
  S.Def->setReg(V);
  S.Def->setIsDead(S.Uses.empty());
  for (auto [MO, SubIdx] : S.Uses) {
    MO->setReg(V);
    MO->setSubReg(SubIdx);
    MO->setIsKill(false);
  }
}

bool RL78VirtualizeAccumulator::runOnBlock(MachineBasicBlock &MBB) {
  SmallVector<Span, 32> Spans;
  Span Open; // The value currently in AX (or A, or part of AX).
  for (MachineInstr &MI : MBB) {
    if (MI.isDebugInstr()) {
      // A debug use pins nothing, but would be left reading a dead register.
      for (MachineOperand &MO : MI.debug_operands())
        if (MO.isReg() && MO.getReg().isPhysical() &&
            TRI->regsOverlap(MO.getReg(), RL78::RP0))
          Open.OK = false;
      continue;
    }
    // Only operands whose register class the allocator knows (see
    // RL78AccumulatorOperands.def) may become virtual: a split may otherwise
    // move the value out of AX. Calls and branches keep their registers.
    auto Accepts = [&](const MachineOperand &MO) {
      if (MI.isCopy())
        return true;
      return !MI.isCall() && !MI.isBranch() && !MI.isReturn() &&
             RL78InstrInfo::acceptsAccumulator(MI.getOpcode(),
                                               MO.getOperandNo());
    };
    bool Clobbered = false;
    for (const MachineOperand &MO : MI.operands())
      if (MO.isRegMask() && MO.clobbersPhysReg(RL78::RP0))
        Clobbered = true;

    // Reads close nothing; they must name exactly the open register.
    unsigned NumReads = 0;
    bool TiedRead = false;
    for (MachineOperand &MO : MI.operands()) {
      if (!MO.isReg() || !MO.readsReg() || !MO.getReg().isPhysical() ||
          !TRI->regsOverlap(MO.getReg(), RL78::RP0))
        continue;
      // A read of A or X alone of a value in AX reads a subregister of it.
      unsigned SubIdx = 0;
      if (Open.Def && Open.Def->getReg() == RL78::RP0 &&
          MO.getReg() != RL78::RP0)
        SubIdx = TRI->getSubRegIndex(RL78::RP0, MO.getReg());
      if (Open.Def && !MO.isImplicit() && !MO.getSubReg() &&
          (MO.getReg() == Open.Def->getReg() || SubIdx) && !MO.isTied() &&
          Accepts(MO)) {
        Open.Uses.push_back({&MO, SubIdx});
        ++NumReads;
      } else if (Open.Def && !MO.isImplicit() && !MO.getSubReg() &&
                 MO.getReg() == Open.Def->getReg() && Accepts(MO)) {
        Open.Uses.push_back({&MO, 0});
        ++NumReads;
        TiedRead |= MO.isTied();
      } else {
        if (Open.Def && Open.OK)
          LLVM_DEBUG(dbgs() << "kept: read by " << MI);
        Open.OK = false;
      }
    }
    // `ADDW AX, AX`: two-address lowering would copy the tied operand and
    // leave two values that both have to be in AX.
    if (TiedRead && NumReads > 1)
      Open.OK = false;

    // Writes end the open value. A new span starts at a lone explicit write
    // of all of AX or A.
    MachineOperand *NewDef = nullptr;
    bool Other = Clobbered;
    for (MachineOperand &MO : MI.operands()) {
      if (!MO.isReg() || !MO.isDef() || !MO.getReg().isPhysical() ||
          !TRI->regsOverlap(MO.getReg(), RL78::RP0))
        continue;
      if (!NewDef && !MO.isImplicit() && !MO.getSubReg() &&
          accClass(MO.getReg()) && Accepts(MO))
        NewDef = &MO;
      else
        Other = true;
    }
    if (Other && Open.Def && Open.OK)
      LLVM_DEBUG(dbgs() << "kept: written by " << MI);
    if (!NewDef && !Other)
      continue;
    // A write of A leaves X of an open AX value in place.
    if (Open.Def && !(NewDef && !Other &&
                      TRI->isSubRegisterEq(NewDef->getReg(),
                                           Open.Def->getReg())))
      Open.OK = false;
    int Prev = -1;
    if (Open.Def) {
      Prev = Spans.size();
      Spans.push_back(Open);
    }
    Open = Span();
    Open.Def = NewDef;
    Open.OK = NewDef && !Other && !MI.isInlineAsm();
    if (NewDef && NewDef->isTied()) {
      // Tied to a read of the previous value, or of something not in a span.
      Open.TiedFrom = Prev;
      if (Prev < 0 || MI.getOperand(MI.findTiedOperandIdx(
                                        NewDef->getOperandNo())).getReg() !=
                          Spans[Prev].Def->getReg())
        Open.OK = false;
    }
  }
  if (Open.Def) {
    for (const MachineBasicBlock *Succ : MBB.successors())
      for (const auto &LI : Succ->liveins())
        if (TRI->regsOverlap(LI.PhysReg, RL78::RP0))
          Open.OK = false;
    // Without liveness of the return value (it is used implicitly by the
    // return), the last value in AX may be live out.
    if (MBB.succ_empty() || MBB.isReturnBlock())
      Open.OK = false;
    Spans.push_back(Open);
  }

  // A span and the one it is tied to share a register: give up on both if
  // either has to stay physical. Ties only point backwards, so one pass back
  // and one forward settle every chain.
  for (int I = Spans.size() - 1; I >= 0; --I)
    if (!Spans[I].OK && Spans[I].TiedFrom >= 0)
      Spans[Spans[I].TiedFrom].OK = false;
  for (Span &S : Spans)
    if (S.TiedFrom >= 0 && !Spans[S.TiedFrom].OK)
      S.OK = false;

  bool Changed = false;
  for (Span &S : Spans) {
    if (!S.OK) {
      ++NumKept;
      continue;
    }
    rewrite(S);
    ++NumSpans;
    Changed = true;
  }
  return Changed;
}

bool RL78VirtualizeAccumulator::runOnMachineFunction(MachineFunction &MF) {
  if (AccCensus) {
    const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();
    for (MachineBasicBlock &MBB : MF)
      for (MachineInstr &MI : MBB) {
        if (MI.isCopy() || MI.isDebugInstr() || MI.isPHI() ||
            MI.isInlineAsm() || MI.isRegSequence() || MI.isInsertSubreg() ||
            MI.isSubregToReg() || MI.isImplicitDef())
          continue;
        for (unsigned I = 0, E = MI.getNumExplicitOperands(); I != E; ++I) {
          const MachineOperand &MO = MI.getOperand(I);
          if (!MO.isReg() || !MO.getReg())
            continue;
          const char *K = MO.getReg() == RL78::RP0 ? "AX"
                          : MO.getReg() == RL78::R1 ? "A"
                                                    : "other";
          errs() << "ACCOP " << TII->getName(MI.getOpcode()) << " " << I
                 << " " << K << "\n";
        }
      }
  }
  if (!RL78VirtualAcc)
    return false;
  MRI = &MF.getRegInfo();
  TRI = MF.getSubtarget().getRegisterInfo();
  if (!MRI->isSSA())
    return false;
  bool Changed = false;
  // Moving spans is an optimization; the widening below is not (the
  // allocator cannot keep a narrowed value in AX across a pinned use of AX),
  // so it also runs on optnone functions.
  if (!WidenOnly && !skipFunction(MF.getFunction()))
    for (MachineBasicBlock &MBB : MF)
      Changed |= runOnBlock(MBB);

  // Instruction selection gives a copy of an accumulator result the class of
  // that result; widen every value that no operand pins to AX or A. Done
  // first right after selection, so that the SSA optimizations and
  // RL78ConstPropAndOpSwap see through the copies, and again here.
  for (unsigned I = 0, E = MRI->getNumVirtRegs(); I != E; ++I) {
    Register R = Register::index2VirtReg(I);
    if (MRI->reg_nodbg_empty(R))
      continue;
    const TargetRegisterClass *RC = MRI->getRegClass(R);
    if (RC == &RL78::RL78AXRPRegClass || RC == &RL78::RL78ARegRegClass) {
      if (MRI->recomputeRegClass(R)) {
        ++NumWidened;
        Changed = true;
        // `%r = COPY %s` is now a plain copy: use %s instead.
        MachineInstr *Def = MRI->getUniqueVRegDef(R);
        if (Def && Def->isCopy() && !Def->getOperand(1).getSubReg() &&
            Def->getOperand(1).getReg().isVirtual()) {
          Register Src = Def->getOperand(1).getReg();
          if (MRI->getRegClass(R)->hasSubClassEq(MRI->getRegClass(Src))) {
            MRI->clearKillFlags(Src);
            MRI->replaceRegWith(R, Src);
            Def->eraseFromParent();
          }
        }
      }
    }
  }
  return Changed;
}

//===----------------------------------------------------------------------===//
// Right before allocation: one instruction reading two different values that
// both have to be in AX (or A) cannot be allocated. The coalescer creates such
// instructions when it keeps a value in AX: `CMPW AX, rp` with the value in
// AX and rp just loaded through AX, or `ADDW AX, rp` with AX still pinned.
// Read each such operand that does not need AX through a copy in its wider
// class; the allocator then has a choice.
//===----------------------------------------------------------------------===//

#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/SlotIndexes.h"

STATISTIC(NumSeparated, "Number of accumulator operands read through a copy");

namespace {
class RL78SeparateAccumulatorOperands : public MachineFunctionPass {
public:
  static char ID;
  RL78SeparateAccumulatorOperands() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 separate operands pinned to AX/A";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    AU.addRequired<LiveIntervalsWrapperPass>();
    AU.addPreserved<LiveIntervalsWrapperPass>();
    AU.addRequired<SlotIndexesWrapperPass>();
    AU.addPreserved<SlotIndexesWrapperPass>();
    AU.setPreservesAll();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;
};
} // end anonymous namespace

char RL78SeparateAccumulatorOperands::ID = 0;

FunctionPass *llvm::createRL78SeparateAccumulatorOperandsPass() {
  return new RL78SeparateAccumulatorOperands();
}

static bool isSingleAccClass(const TargetRegisterClass *RC) {
  return RC == &RL78::RL78AXRPRegClass || RC == &RL78::RL78ARegRegClass;
}

bool RL78SeparateAccumulatorOperands::runOnMachineFunction(
    MachineFunction &MF) {
  if (!RL78VirtualAcc)
    return false;
  MachineRegisterInfo &MRI = MF.getRegInfo();
  const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();
  LiveIntervals &LIS = getAnalysis<LiveIntervalsWrapperPass>().getLIS();
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF)
    for (MachineInstr &MI : MBB) {
      if (MI.isCopy() || MI.isDebugInstr())
        continue;
      SmallVector<unsigned, 4> AccUses;
      SmallVector<Register, 4> Distinct;
      for (const MachineOperand &MO : MI.uses()) {
        // A value still in physical AX/A counts as one more.
        if (MO.isReg() && MO.getReg().isPhysical() && MO.readsReg() &&
            MF.getSubtarget().getRegisterInfo()->regsOverlap(MO.getReg(),
                                                             RL78::RP0)) {
          if (!llvm::is_contained(Distinct, Register(RL78::RP0)))
            Distinct.push_back(RL78::RP0);
          continue;
        }
        if (!MO.isReg() || !MO.getReg().isVirtual() || MO.isUndef())
          continue;
        if (!isSingleAccClass(MRI.getRegClass(MO.getReg())))
          continue;
        AccUses.push_back(MO.getOperandNo());
        if (!llvm::is_contained(Distinct, MO.getReg()))
          Distinct.push_back(MO.getReg());
      }
      if (Distinct.size() < 2)
        continue;
      for (unsigned Idx : AccUses) {
        MachineOperand &MO = MI.getOperand(Idx);
        if (MO.isTied() || MO.getSubReg())
          continue;
        const TargetRegisterClass *RC = TII->getRegClass(MI.getDesc(), Idx);
        if (!RC || isSingleAccClass(RC) || RC->getNumRegs() < 2)
          continue;
        Register V = MO.getReg();
        Register N = MRI.createVirtualRegister(RC);
        MachineInstr *Copy =
            BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(TargetOpcode::COPY), N)
                .addReg(V);
        LIS.InsertMachineInstrInMaps(*Copy);
        MO.setReg(N);
        MO.setIsKill(false);
        LIS.createAndComputeVirtRegInterval(N);
        LIS.shrinkToUses(&LIS.getInterval(V));
        ++NumSeparated;
        Changed = true;
      }
    }
  return Changed;
}
