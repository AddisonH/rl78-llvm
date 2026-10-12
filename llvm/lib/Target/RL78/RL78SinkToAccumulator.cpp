//===-- RL78SinkToAccumulator.cpp - Compute AX values where they are used -===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Most RL78 instructions produce their result in AX (A for 8 bits) and read
// one operand from it. The custom inserters pin those operands with copies,
// so a value travels as
//
//   $rp0 = LOAD16_rp_rpi ...        ; the "unit" that computes the value
//   %v = COPY $rp0
//   ...                             ; other AX traffic
//   $rp0 = COPY %v                  ; the consumer wants it back in AX
//   ... = OP $rp0, ...
//
// The physical register operands serialize every such unit, so the machine
// scheduler cannot reorder them and the SelectionDAG order stands. When it
// computes an AX operand early (MACH_cg computes `B` before `A`, which goes
// through AX into BC), %v needs a second register across the other unit, and
// with four register pairs that is often a spill.
//
// When %v has no other use, move the unit down to the copy and let it write
// AX directly; %v disappears. Runs on SSA machine code before register
// allocation; the motion is local to a block and skipped whenever it could
// change behaviour (memory, physical registers) or lengthen the live range of
// a unit's inputs.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78InstrInfo.h"
#include "RL78Subtarget.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetRegisterInfo.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "rl78-sink-to-acc"
using namespace llvm;

STATISTIC(NumSunk, "Number of AX/A units moved to their consumer");

static cl::opt<bool>
    EnableSinkToAcc("rl78-sink-to-acc", cl::Hidden, cl::init(true),
                    cl::desc("Compute AX operands right before their use"));

static cl::opt<unsigned> SinkWindow(
    "rl78-sink-to-acc-window", cl::Hidden, cl::init(40),
    cl::desc("Maximum number of instructions a unit is moved across"));

namespace {
class RL78SinkToAccumulator : public MachineFunctionPass {
public:
  static char ID;
  RL78SinkToAccumulator() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 compute AX operands where they are used";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  MachineRegisterInfo *MRI = nullptr;
  const TargetRegisterInfo *TRI = nullptr;

  bool trySink(MachineInstr &Use);
  bool trySinkDef(MachineInstr &Use);
  bool physRegLiveAt(MachineBasicBlock::iterator I, MCRegister R) const;
};
} // end anonymous namespace

char RL78SinkToAccumulator::ID = 0;

FunctionPass *llvm::createRL78SinkToAccumulatorPass() {
  return new RL78SinkToAccumulator();
}

static bool isAccumulator(Register R) {
  return R == RL78::RP0 || R == RL78::R1;
}

// Whether physical register R (or an overlapping one) is read at or after I
// before being completely redefined.
bool RL78SinkToAccumulator::physRegLiveAt(MachineBasicBlock::iterator I,
                                          MCRegister R) const {
  MachineBasicBlock &MBB = *I->getParent();
  for (auto E = MBB.end(); I != E; ++I) {
    if (I->isDebugInstr())
      continue;
    bool Defined = false;
    for (const MachineOperand &MO : I->operands()) {
      if (!MO.isReg() || !MO.getReg().isPhysical() ||
          !TRI->regsOverlap(MO.getReg(), R))
        continue;
      if (MO.readsReg())
        return true;
      if (MO.isDef() && !MO.getSubReg() && TRI->isSubRegisterEq(MO.getReg(), R))
        Defined = true;
    }
    if (Defined)
      return false;
  }
  for (const MachineBasicBlock *Succ : MBB.successors())
    for (const auto &LI : Succ->liveins())
      if (TRI->regsOverlap(LI.PhysReg, R))
        return true;
  return false;
}

// Use is `$rp0 = COPY %v` (or `$r1 = COPY %v`).
bool RL78SinkToAccumulator::trySink(MachineInstr &Use) {
  if (!Use.isCopy())
    return false;
  Register Acc = Use.getOperand(0).getReg();
  Register V = Use.getOperand(1).getReg();
  if (!isAccumulator(Acc) || !V.isVirtual() || Use.getOperand(1).getSubReg() ||
      !MRI->hasOneNonDBGUse(V))
    return false;
  MachineInstr *Def = MRI->getUniqueVRegDef(V);
  if (!Def || Def->getParent() != Use.getParent() || !Def->isCopy() ||
      Def->getOperand(1).getReg() != Acc || Def->getOperand(1).getSubReg())
    return false;
  MachineBasicBlock &MBB = *Use.getParent();

  // Collect the unit: the instructions before Def that compute Acc, back to
  // the point where every physical register they read has been set by them.
  SmallVector<MachineInstr *, 4> Unit;
  SmallVector<Register, 4> Needed{Acc};
  MachineBasicBlock::iterator I = Def->getIterator();
  while (!Needed.empty()) {
    if (I == MBB.begin())
      return false;
    --I;
    MachineInstr &MI = *I;
    if (MI.isDebugInstr())
      return false;
    if (MI.isCall() || MI.isTerminator() || MI.mayStore() ||
        MI.hasUnmodeledSideEffects() || MI.hasOrderedMemoryRef() ||
        MI.isPHI() || MI.isInlineAsm())
      return false;
    bool DefinesNeeded = false;
    for (const MachineOperand &MO : MI.operands()) {
      if (!MO.isReg() || !MO.isDef() || !MO.getReg())
        continue;
      // The unit may define no virtual register: moving it would move that
      // definition below its uses.
      if (MO.getReg().isVirtual())
        return false;
      for (Register N : Needed)
        if (TRI->isSubRegisterEq(MO.getReg(), N))
          DefinesNeeded = true;
    }
    if (!DefinesNeeded)
      return false;
    Unit.push_back(&MI);
    // Retire what this instruction defines, then add what it reads.
    llvm::erase_if(Needed, [&](Register N) {
      for (const MachineOperand &MO : MI.operands())
        if (MO.isReg() && MO.isDef() && MO.getReg() &&
            TRI->isSubRegisterEq(MO.getReg(), N))
          return true;
      return false;
    });
    for (const MachineOperand &MO : MI.operands()) {
      if (!MO.isReg() || !MO.readsReg() || !MO.getReg().isPhysical())
        continue;
      Register R = MO.getReg();
      // Implicit reads of the subregisters of a register the instruction
      // also reads (ADDW's implicit $r0/$r1) are covered by that register.
      if (MRI->isReserved(R) || MRI->isConstantPhysReg(R))
        continue;
      bool Covered = false;
      for (Register N : Needed)
        if (TRI->isSubRegisterEq(N, R))
          Covered = true;
      if (!Covered)
        Needed.push_back(R);
    }
    // Implicit reads such as ADDW_rp_rp's `implicit $r0, implicit $r1` are
    // subregisters of the tied $rp0 it reads; collapse them.
    llvm::erase_if(Needed, [&](Register N) {
      for (Register M : Needed)
        if (M != N && TRI->isSubRegister(M, N))
          return true;
      return false;
    });
    if (Unit.size() > 4)
      return false;
  }
  // The unit's first instruction is the last one collected.
  std::reverse(Unit.begin(), Unit.end());

  // Every physical register the unit defines must be consumed inside the unit
  // or be dead, and must not be live where the unit lands.
  SmallVector<MCRegister, 8> Clobbers;
  for (MachineInstr *MI : Unit)
    for (const MachineOperand &MO : MI->operands())
      if (MO.isReg() && MO.isDef() && MO.getReg().isPhysical())
        Clobbers.push_back(MO.getReg());

  bool UnitLoads = llvm::any_of(Unit, [](MachineInstr *MI) {
    return MI->mayLoad();
  });

  // The instructions the unit moves across.
  unsigned N = 0;
  for (auto J = std::next(Def->getIterator()); J != Use.getIterator(); ++J) {
    if (J->isDebugInstr())
      continue;
    if (++N > SinkWindow)
      return false;
    if (J->isCall() || J->hasUnmodeledSideEffects() || J->isInlineAsm())
      return false;
    if (UnitLoads && (J->mayStore() || J->hasOrderedMemoryRef()))
      return false;
    for (const MachineOperand &MO : J->operands()) {
      if (!MO.isReg() || !MO.getReg().isPhysical())
        continue;
      for (MachineInstr *UMI : Unit)
        for (const MachineOperand &UO : UMI->operands())
          // The accumulator itself may be used and redefined in between:
          // the unit's value is only read by Def, and Use redefines it.
          if (UO.isReg() && UO.getReg().isPhysical() &&
              !MRI->isReserved(UO.getReg()) &&
              !TRI->isSubRegisterEq(Acc, UO.getReg()) &&
              TRI->regsOverlap(UO.getReg(), MO.getReg()) &&
              (UO.isDef() || MO.isDef()))
            return false;
    }
  }
  for (MCRegister R : Clobbers)
    if (R != Acc.asMCReg() && !MRI->isReserved(R) && physRegLiveAt(Use.getIterator(), R))
      return false;

  // Do not lengthen the live ranges of the unit's inputs: each one must be
  // used again at or after Use, or outside this block.
  SmallPtrSet<MachineInstr *, 4> InUnit(Unit.begin(), Unit.end());
  for (MachineInstr *MI : Unit)
    for (const MachineOperand &MO : MI->uses()) {
      if (!MO.isReg() || !MO.getReg().isVirtual())
        continue;
      bool LiveOn = false;
      for (MachineInstr &UI : MRI->use_nodbg_instructions(MO.getReg())) {
        if (InUnit.count(&UI))
          continue;
        if (UI.getParent() != &MBB || UI.isPHI()) {
          LiveOn = true;
          break;
        }
        // Same block: is UI at or after Use?
        for (auto K = Use.getIterator(); K != MBB.end(); ++K)
          if (&*K == &UI) {
            LiveOn = true;
            break;
          }
        if (LiveOn)
          break;
      }
      if (!LiveOn)
        return false;
      // The input's earlier kill now happens later; clear kill flags.
      MRI->clearKillFlags(MO.getReg());
    }

  LLVM_DEBUG(dbgs() << "Sinking AX unit for " << printReg(V) << " to "
                    << Use);
  for (MachineInstr *MI : Unit)
    MBB.splice(Use.getIterator(), &MBB, MI->getIterator());
  // Debug uses of V lose their value.
  for (MachineOperand &MO :
       llvm::make_early_inc_range(MRI->use_operands(V)))
    if (MO.getParent()->isDebugInstr())
      MO.setReg(Register());
  Def->eraseFromParent();
  Use.eraseFromParent();
  ++NumSunk;
  return true;
}

// The same for a value that is in the accumulator by its register class:
//
//   %v:rl78axrp = MOVW_AX_mRP %p    ; the operand MACH reads from AX
//   %t:rl78axrp = MOVW_AX_mRPi %q, 2
//   %b:rl78bcrp = COPY %t
//   ... = MACH_CG ..., %v, %b
//
// %v and %t both want AX, and %v is the one that waits, in another register
// or on the stack. Move the definition of %v down to its one use when it
// crosses the definition of another accumulator value on the way.
bool RL78SinkToAccumulator::trySinkDef(MachineInstr &Use) {
  if (Use.isPHI() || Use.isDebugInstr())
    return false;
  // A copy into a class with a choice of registers is as good a place to
  // wait as any. And where the two operands can change places, the one
  // computed last is the one that stays in the accumulator anyway (sinking
  // into these cost Embench nettle-sha256 8%).
  if (Use.isCopy() && (!Use.getOperand(0).getReg().isVirtual() ||
                       MRI->getRegClass(Use.getOperand(0).getReg())
                               ->getNumRegs() > 1))
    return false;
  switch (Use.getOpcode()) {
  case RL78::ADDW_AX_rp:
  case RL78::ADD_A_r:
  case RL78::AND_A_r:
  case RL78::OR_A_r:
  case RL78::XOR_A_r:
  case RL78::AND16_AX_rp:
  case RL78::OR16_AX_rp:
  case RL78::XOR16_AX_rp:
    return false;
  }
  MachineBasicBlock &MBB = *Use.getParent();
  auto IsAccClass = [&](Register R) {
    if (!R.isVirtual())
      return false;
    const TargetRegisterClass *RC = MRI->getRegClass(R);
    return RC == &RL78::RL78AXRPRegClass || RC == &RL78::RL78ARegRegClass;
  };
  for (const MachineOperand &UseMO : Use.uses()) {
    if (!UseMO.isReg() || UseMO.getSubReg() || !IsAccClass(UseMO.getReg()))
      continue;
    Register V = UseMO.getReg();
    if (!MRI->hasOneNonDBGUse(V))
      continue;
    MachineInstr *Def = MRI->getUniqueVRegDef(V);
    if (!Def || Def->getParent() != &MBB || Def->isPHI() || Def->isCall() ||
        Def->mayStore() || Def->hasUnmodeledSideEffects() ||
        Def->hasOrderedMemoryRef() || Def->isInlineAsm() ||
        Def->getNumExplicitDefs() != 1)
      continue;
    // The flags are the only physical register it may write, and nothing
    // may be waiting for them where it lands; it reads none but SP.
    bool Movable = true, WritesFlags = false;
    for (const MachineOperand &MO : Def->operands()) {
      if (!MO.isReg() || !MO.getReg().isPhysical())
        continue;
      if (MO.isDef() && MO.getReg() == RL78::CCreg && MO.isDead())
        WritesFlags = true;
      else if (MO.isDef() || !MRI->isReserved(MO.getReg()))
        Movable = false;
    }
    if (!Movable || (WritesFlags && physRegLiveAt(Use.getIterator(), RL78::CCreg)))
      continue;

    bool CrossesAcc = false, Safe = true;
    unsigned N = 0;
    for (auto J = std::next(Def->getIterator()); J != Use.getIterator(); ++J) {
      if (J->isDebugInstr())
        continue;
      if (++N > SinkWindow || J->isCall() || J->hasUnmodeledSideEffects() ||
          J->isInlineAsm() || J->modifiesRegister(RL78::SPreg, TRI) ||
          (Def->mayLoad() && (J->mayStore() || J->hasOrderedMemoryRef()))) {
        Safe = false;
        break;
      }
      for (const MachineOperand &MO : J->operands()) {
        if (!MO.isReg() || !MO.isDef())
          continue;
        if (IsAccClass(MO.getReg()))
          CrossesAcc = true;
        // Not below an argument or return value set up in its register:
        // that register may be the one V or an input of Def has to be in.
        if (MO.getReg().isPhysical() && MO.getReg() != RL78::CCreg)
          Safe = false;
      }
      if (!Safe)
        break;
    }
    if (!Safe || !CrossesAcc)
      continue;

    // Its inputs must be used again at or after Use, or outside this block,
    // so that their live ranges stay as they are. One may be lengthened
    // if it can live outside the accumulator: it then waits where V would
    // have waited.
    unsigned Lengthened = 0;
    for (const MachineOperand &MO : Def->uses()) {
      if (!MO.isReg() || !MO.getReg().isVirtual())
        continue;
      bool LiveOn = false;
      for (MachineInstr &UI : MRI->use_nodbg_instructions(MO.getReg())) {
        if (&UI == Def)
          continue;
        if (UI.getParent() != &MBB || UI.isPHI()) {
          LiveOn = true;
          break;
        }
        for (auto K = Use.getIterator(); K != MBB.end() && !LiveOn; ++K)
          LiveOn = &*K == &UI;
        if (LiveOn)
          break;
      }
      if (!LiveOn)
        Lengthened += IsAccClass(MO.getReg()) || MO.getSubReg() ? 2 : 1;
    }
    if (Lengthened > 1)
      continue;

    LLVM_DEBUG(dbgs() << "Sinking " << *Def << "  to " << Use);
    for (const MachineOperand &MO : Def->uses())
      if (MO.isReg() && MO.getReg().isVirtual())
        MRI->clearKillFlags(MO.getReg());
    // Debug uses of V in between lose their value.
    for (MachineOperand &MO : llvm::make_early_inc_range(MRI->use_operands(V)))
      if (MO.getParent()->isDebugInstr())
        MO.setReg(Register());
    MBB.splice(Use.getIterator(), &MBB, Def->getIterator());
    ++NumSunk;
    return true;
  }
  return false;
}

bool RL78SinkToAccumulator::runOnMachineFunction(MachineFunction &MF) {
  if (!EnableSinkToAcc || skipFunction(MF.getFunction()))
    return false;
  MRI = &MF.getRegInfo();
  TRI = MF.getSubtarget().getRegisterInfo();
  if (!MRI->isSSA())
    return false;
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF)
    for (MachineInstr &MI : llvm::make_early_inc_range(MBB))
      Changed |= trySink(MI) || trySinkDef(MI);
  return Changed;
}
