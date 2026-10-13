//===-- RL78AccumulatorCopies.cpp - Copies around A and AX ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Most operations compute in A or AX, so the register allocator moves values
// into and out of them. Two shapes of those copies can be told only once the
// registers are known. They are replaced here, while the copies are still
// COPY instructions.
//
// The other value of a commutative operation was in the accumulator:
//
//   $rp6 = COPY $rp0
//   $rp0 = COPY $rp2
//   $rp0 = AND16_AX_rp $rp0, killed $rp6  ->  $rp0 = AND16_AX_rp $rp0, $rp2
//
// A value in another register is computed on in the accumulator, whose own
// value waits in a third register: an exchange each way does the same.
//
//   $rp4 = COPY $rp0                      ->  XCHW AX, BC
//   $rp0 = COPY $rp2
//   $rp0 = SHRW_AX_n $rp0, 1                  $rp0 = SHRW_AX_n $rp0, 1
//   $rp2 = COPY $rp0                      ->  XCHW AX, BC
//   $rp0 = COPY killed $rp4
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78InstrInfo.h"
#include "RL78Subtarget.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"

#define DEBUG_TYPE "rl78-accumulator-copies"
using namespace llvm;

STATISTIC(NumCommuted, "Number of operations commuted to what A or AX holds");
STATISTIC(NumExchanged, "Number of saves of A or AX replaced by exchanges");

namespace {
class RL78AccumulatorCopies : public MachineFunctionPass {
public:
  static char ID;
  RL78AccumulatorCopies() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 copies around A and AX";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  const RL78InstrInfo *TII = nullptr;
  const TargetRegisterInfo *TRI = nullptr;

  bool commute(MachineInstr &Save);
  bool exchange(MachineInstr &Save);
};
} // end anonymous namespace

char RL78AccumulatorCopies::ID = 0;

FunctionPass *llvm::createRL78AccumulatorCopiesPass() {
  return new RL78AccumulatorCopies();
}

// OP A, r and OP AX, rp whose two values may change places.
static bool isCommutative(unsigned Opcode) {
  switch (Opcode) {
  case RL78::ADD_A_r:
  case RL78::AND_A_r:
  case RL78::OR_A_r:
  case RL78::XOR_A_r:
  case RL78::ADDW_AX_rp:
  case RL78::AND16_AX_rp:
  case RL78::OR16_AX_rp:
  case RL78::XOR16_AX_rp:
    return true;
  }
  return false;
}

// A copy between the accumulator and another register of its size: which
// accumulator and which register, if \p MI is one.
static bool isCopyOut(const MachineInstr &MI, MCRegister &Acc, MCRegister &R) {
  if (!MI.isCopy() || MI.getOperand(0).getSubReg() ||
      MI.getOperand(1).getSubReg())
    return false;
  Register Dst = MI.getOperand(0).getReg(), Src = MI.getOperand(1).getReg();
  if (Src == RL78::RP0 && RL78::RL78BCDEHLRegClass.contains(Dst))
    Acc = RL78::RP0;
  else if (Src == RL78::R1 && RL78::RL78XBCEDHLRegRegClass.contains(Dst))
    Acc = RL78::R1;
  else
    return false;
  R = Dst.asMCReg();
  return true;
}

static bool isCopyIn(const MachineInstr &MI, MCRegister Acc, MCRegister &R) {
  if (!MI.isCopy() || MI.getOperand(0).getSubReg() ||
      MI.getOperand(1).getSubReg() || MI.getOperand(0).getReg() != Acc)
    return false;
  Register Src = MI.getOperand(1).getReg();
  if (!(Acc == RL78::RP0 ? RL78::RL78BCDEHLRegClass.contains(Src)
                         : RL78::RL78XBCEDHLRegRegClass.contains(Src)))
    return false;
  R = Src.asMCReg();
  return true;
}

// R = COPY acc; acc = COPY S; acc = OP acc, killed R.
bool RL78AccumulatorCopies::commute(MachineInstr &Save) {
  MachineBasicBlock &MBB = *Save.getParent();
  MCRegister Acc, R, S;
  if (!isCopyOut(Save, Acc, R))
    return false;
  MachineBasicBlock::iterator Load =
      next_nodbg(MachineBasicBlock::iterator(Save), MBB.end());
  if (Load == MBB.end() || !isCopyIn(*Load, Acc, S) || S == R)
    return false;
  MachineBasicBlock::iterator Op = next_nodbg(Load, MBB.end());
  if (Op == MBB.end() || !isCommutative(Op->getOpcode()) ||
      Op->getOperand(1).getReg() != Acc || Op->getOperand(2).getReg() != R ||
      !Op->getRegClassConstraint(2, TII, TRI)->contains(S) ||
      TII->isLiveBefore(MBB, std::next(Op), R))
    return false;
  Op->getOperand(2).setReg(S);
  Op->getOperand(2).setIsKill(false);
  Load->eraseFromParent();
  Save.eraseFromParent();
  ++NumCommuted;
  return true;
}

// T = COPY acc; acc = COPY R; ...; R = COPY acc; acc = COPY killed T.
bool RL78AccumulatorCopies::exchange(MachineInstr &Save) {
  MachineBasicBlock &MBB = *Save.getParent();
  MCRegister Acc, T, R, R2, T2;
  if (!isCopyOut(Save, Acc, T))
    return false;
  MachineBasicBlock::iterator Load =
      next_nodbg(MachineBasicBlock::iterator(Save), MBB.end());
  if (Load == MBB.end() || !isCopyIn(*Load, Acc, R) || R == T)
    return false;

  // The operations in between leave T and R alone.
  MachineBasicBlock::iterator Store = next_nodbg(Load, MBB.end());
  for (unsigned Left = 8;; Store = next_nodbg(Store, MBB.end())) {
    if (Store == MBB.end() || !Left--)
      return false;
    MCRegister A2;
    if (isCopyOut(*Store, A2, R2) && A2 == Acc && R2 == R)
      break;
    if (Store->isCall() || Store->isTerminator() || Store->isInlineAsm())
      return false;
    for (const MachineOperand &MO : Store->operands()) {
      if (MO.isRegMask())
        return false;
      if (MO.isReg() && MO.getReg() &&
          (TRI->regsOverlap(MO.getReg(), T) || TRI->regsOverlap(MO.getReg(), R)))
        return false;
    }
  }
  MachineBasicBlock::iterator Restore = next_nodbg(Store, MBB.end());
  if (Restore == MBB.end() || !isCopyIn(*Restore, Acc, T2) || T2 != T ||
      TII->isLiveBefore(MBB, std::next(Restore), T))
    return false;

  unsigned Opcode =
      Acc == RL78::RP0 ? unsigned(RL78::XCHW_AX_rp) : TII->getXCHOpcode(R);
  for (MachineInstr *At : {&*Load, &*Restore})
    BuildMI(MBB, At, At->getDebugLoc(), TII->get(Opcode))
        .addReg(Acc, RegState::Define)
        .addReg(R, RegState::Define)
        .addReg(Acc)
        .addReg(R);
  Save.eraseFromParent();
  Load->eraseFromParent();
  Store->eraseFromParent();
  Restore->eraseFromParent();
  ++NumExchanged;
  return true;
}

bool RL78AccumulatorCopies::runOnMachineFunction(MachineFunction &MF) {
  TII = static_cast<const RL78InstrInfo *>(MF.getSubtarget().getInstrInfo());
  TRI = MF.getSubtarget().getRegisterInfo();
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    bool BlockChanged = false;
    for (MachineBasicBlock::iterator I = MBB.begin(); I != MBB.end();) {
      MachineInstr &MI = *I;
      // Both replace MI and what follows it: go on from the instruction
      // before, which may now start a shape of its own.
      MachineBasicBlock::iterator Prev =
          I == MBB.begin() ? MBB.end() : std::prev(I);
      if (MI.isCopy() && (commute(MI) || exchange(MI))) {
        BlockChanged = true;
        I = Prev == MBB.end() ? MBB.begin() : std::next(Prev);
        continue;
      }
      ++I;
    }
    if (BlockChanged)
      TII->setExchangeFlags(MBB);
    Changed |= BlockChanged;
  }
  return Changed;
}
