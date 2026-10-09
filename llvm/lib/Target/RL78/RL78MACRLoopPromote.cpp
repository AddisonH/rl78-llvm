//===-- RL78MACRLoopPromote.cpp - Keep MACH_cg accumulators in MACR ---------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// A multiply-accumulate loop (sum += a[i] * b[i]) selects MACH_cg/MACHU_cg, whose
// accumulator is the MACRL/MACRH register pair. The loop-carried sum is an
// ordinary 16-bit virtual register pair, so every iteration copies it into
// MACR before the MACH_cg and back out after it; MACR is memory mapped
// (0xffff0/2), so each of those copies is a load or store through AX.
//
// When MACR is otherwise unused in the loop, give the loop-carried values the
// MACRL/MACRH register classes instead: the copies around the MACH_cg become
// coalescable, MACR is written once in the preheader and read once in the
// exit block. The classes have one register each, so the conditions below
// make sure no other MACR value is ever live at the same time.
//
// Runs on SSA machine code before register allocation.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78InstrInfo.h"
#include "RL78Subtarget.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineLoopInfo.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "rl78-macr-loop-promote"
using namespace llvm;

static cl::opt<bool> EnableMACRLoopPromote(
    "rl78-macr-loop-promote", cl::Hidden, cl::init(true),
    cl::desc("Keep MACH_cg accumulators in MACR across loops"));

namespace {
class RL78MACRLoopPromote : public MachineFunctionPass {
public:
  static char ID;
  RL78MACRLoopPromote() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 keep MACH_cg accumulators in MACR across loops";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<MachineLoopInfoWrapperPass>();
    AU.addPreserved<MachineLoopInfoWrapperPass>();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  MachineRegisterInfo *MRI = nullptr;
  const TargetInstrInfo *TII = nullptr;

  bool promote(MachineInstr &Mac, MachineLoop &L);
};
} // end anonymous namespace

char RL78MACRLoopPromote::ID = 0;

FunctionPass *llvm::createRL78MACRLoopPromotePass() {
  return new RL78MACRLoopPromote();
}

static bool isMAC(const MachineInstr &MI) {
  return MI.getOpcode() == RL78::MACH_CG || MI.getOpcode() == RL78::MACHU_CG;
}

static bool isMACRClass(const TargetRegisterClass *RC) {
  return RC == &RL78::RL78RegMACRLRegClass ||
         RC == &RL78::RL78RegMACRHRegClass;
}

// True if anything in the loop other than Mac may read or write MACR.
static bool loopTouchesMACR(MachineLoop &L, const MachineInstr &Mac,
                            const MachineRegisterInfo &MRI) {
  for (MachineBasicBlock *MBB : L.blocks())
    for (const MachineInstr &MI : *MBB) {
      if (&MI == &Mac)
        continue;
      if (isMAC(MI) || MI.isCall() || MI.isInlineAsm())
        return true;
      for (const MachineOperand &MO : MI.operands()) {
        if (MO.isRegMask())
          return true;
        if (!MO.isReg() || !MO.getReg())
          continue;
        Register R = MO.getReg();
        if (R == RL78::MACRL || R == RL78::MACRH)
          return true;
        // COPYs into and out of Mac's own operands are expected; any other
        // MACR-class value would compete for the single register.
        if (R.isVirtual() && isMACRClass(MRI.getRegClass(R)) && !MI.isCopy())
          return true;
      }
    }
  return false;
}

bool RL78MACRLoopPromote::promote(MachineInstr &Mac, MachineLoop &L) {
  MachineBasicBlock *Header = L.getHeader();
  MachineBasicBlock *Exiting = L.getExitingBlock();
  MachineBasicBlock *Exit = L.getExitBlock();
  MachineBasicBlock *Preheader = L.getLoopPreheader();
  if (!Exiting || !Exit || !Preheader || loopTouchesMACR(L, Mac, *MRI))
    return false;

  struct Half {
    MachineInstr *Phi;
    Register PhiReg, Next, Init;
    const TargetRegisterClass *RC;
  };
  Half H[2];
  for (unsigned K = 0; K < 2; ++K) {
    // In = COPY PhiReg; PhiReg = PHI Init, Preheader, Next, Latch;
    // Next = COPY Out.
    Register In = Mac.getOperand(2 + K).getReg();
    Register Out = Mac.getOperand(K).getReg();
    MachineInstr *InDef = MRI->getUniqueVRegDef(In);
    if (!InDef || !InDef->isCopy() || !InDef->getOperand(1).getReg().isVirtual())
      return false;
    Register PhiReg = InDef->getOperand(1).getReg();
    MachineInstr *Phi = MRI->getUniqueVRegDef(PhiReg);
    if (!Phi || !Phi->isPHI() || Phi->getParent() != Header ||
        Phi->getNumOperands() != 5 || !MRI->hasOneNonDBGUse(PhiReg) ||
        !MRI->hasOneNonDBGUse(Out))
      return false;
    MachineInstr *OutUse = &*MRI->use_instr_nodbg_begin(Out);
    if (!OutUse->isCopy() || !OutUse->getOperand(0).getReg().isVirtual())
      return false;
    Register Next = OutUse->getOperand(0).getReg();

    Register Init;
    bool SawNext = false;
    for (unsigned I = 1; I < 5; I += 2) {
      MachineBasicBlock *From = Phi->getOperand(I + 1).getMBB();
      Register V = Phi->getOperand(I).getReg();
      if (L.contains(From)) {
        if (V != Next)
          return false;
        SawNext = true;
      } else {
        if (From != Preheader)
          return false;
        Init = V;
      }
    }
    if (!SawNext || !Init)
      return false;

    // Next may be used by the header PHI and after the loop: by PHIs in the
    // exit block (on the loop edge) or by anything the exit dominates.
    for (MachineOperand &MO : MRI->use_nodbg_operands(Next)) {
      MachineInstr &U = *MO.getParent();
      if (&U == Phi)
        continue;
      if (L.contains(U.getParent()))
        return false;
      if (U.isPHI() && (U.getParent() != Exit ||
                        U.getOperand(MO.getOperandNo() + 1).getMBB() !=
                            Exiting))
        return false;
    }
    H[K] = {Phi, PhiReg, Next, Init,
            K == 0 ? &RL78::RL78RegMACRLRegClass : &RL78::RL78RegMACRHRegClass};
  }
  if (H[0].Phi == H[1].Phi)
    return false;

  LLVM_DEBUG(dbgs() << "MACR promote in " << printMBBReference(*Header)
                    << ": " << Mac);

  // Copy the result out on the exit edge; split it if the exit block has
  // other predecessors (e.g. the zero-trip path).
  MachineBasicBlock *CopyOut = Exit;
  if (Exit->pred_size() != 1) {
    CopyOut = Exiting->SplitCriticalEdge(Exit, *this);
    if (!CopyOut)
      return false;
  }

  MachineBasicBlock::iterator PreEnd = Preheader->getFirstTerminator();
  MachineBasicBlock::iterator ExitBegin = CopyOut->getFirstNonPHI();
  DebugLoc DL = Mac.getDebugLoc();
  for (Half &X : H) {
    const TargetRegisterClass *OldRC = MRI->getRegClass(X.Next);
    // Exit: copy the result out once, before anything else uses it.
    Register Result = MRI->createVirtualRegister(OldRC);
    MachineInstr *Out =
        BuildMI(*CopyOut, ExitBegin, DL, TII->get(TargetOpcode::COPY), Result)
            .addReg(X.Next);
    for (MachineOperand &MO :
         llvm::make_early_inc_range(MRI->use_operands(X.Next))) {
      MachineInstr *U = MO.getParent();
      if (U == X.Phi || U == Out || L.contains(U->getParent()))
        continue;
      MO.setReg(Result);
    }
    // Preheader: load the initial value into MACR.
    Register InitM = MRI->createVirtualRegister(X.RC);
    BuildMI(*Preheader, PreEnd, DL, TII->get(TargetOpcode::COPY), InitM)
        .addReg(X.Init);
    for (unsigned I = 1; I < 5; I += 2)
      if (X.Phi->getOperand(I).getReg() == X.Init)
        X.Phi->getOperand(I).setReg(InitM);
    MRI->setRegClass(X.PhiReg, X.RC);
    MRI->setRegClass(X.Next, X.RC);
  }
  return true;
}

bool RL78MACRLoopPromote::runOnMachineFunction(MachineFunction &MF) {
  if (!EnableMACRLoopPromote || skipFunction(MF.getFunction()))
    return false;
  MRI = &MF.getRegInfo();
  TII = MF.getSubtarget().getInstrInfo();
  MachineLoopInfo &MLI = getAnalysis<MachineLoopInfoWrapperPass>().getLI();

  SmallVector<MachineInstr *, 4> Macs;
  for (MachineBasicBlock &MBB : MF)
    for (MachineInstr &MI : MBB)
      if (isMAC(MI) && MLI.getLoopFor(&MBB))
        Macs.push_back(&MI);

  bool Changed = false;
  for (MachineInstr *Mac : Macs)
    Changed |= promote(*Mac, *MLI.getLoopFor(Mac->getParent()));
  return Changed;
}
