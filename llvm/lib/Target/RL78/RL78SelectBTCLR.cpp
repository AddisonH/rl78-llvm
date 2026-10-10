//===-- RL78SelectBTCLR.cpp - Define TargetMachine for RL78 ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
//
//===----------------------------------------------------------------------===//

#include "RL78TargetMachine.h"

using namespace llvm;

namespace {
class RL78SelectBTCLRPass : public MachineFunctionPass {
public:
  RL78SelectBTCLRPass() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 select BTCLR instruction";
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  static char ID;
};

char RL78SelectBTCLRPass::ID = 0;
} // end anonymous namespace

FunctionPass *llvm::createRL78SelectBTCLRPass() {
  return new RL78SelectBTCLRPass();
}

bool RL78SelectBTCLRPass::runOnMachineFunction(MachineFunction &MF) {
  bool Changed = false;
  const TargetInstrInfo *TII = MF.getSubtarget<RL78Subtarget>().getInstrInfo();
  //
  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;
    //
    MachineBasicBlock::iterator I = MBB.getLastNonDebugInstr();
    if (I == MBB.end())
      continue;
    //
    MachineInstr &MI = *I;
    // BT: operands are the tested byte, the bit, the target and the
    // condition.
    unsigned Opc = MI.getOpcode();
    if ((Opc != RL78::BTF_A_b && Opc != RL78::BTF_mHL_b &&
         Opc != RL78::BTF_saddr_b && Opc != RL78::BTF_sfr_b) ||
        MI.getOperand(3).getImm() != RL78CC::RL78CC_Z ||
        !MI.getOperand(2).isMBB())
      continue;
    // The instruction that clears the bit goes: the branch must be the only
    // way into the target.
    MachineBasicBlock *TBB = MI.getOperand(2).getMBB();
    if (TBB->pred_size() != 1)
      continue;
    MachineBasicBlock::iterator First = TBB->getFirstNonDebugInstr();
    if (First == TBB->end())
      continue;
    MachineInstr &firstMI = *First;
    const MachineOperand &Byte = MI.getOperand(0);
    const MachineOperand &Bit = MI.getOperand(1);
    MachineInstrBuilder MIB;
    if (Opc == RL78::BTF_A_b && firstMI.getOpcode() == RL78::AND_A_i8 &&
        firstMI.getOperand(2).getImm() == ~(1 << Bit.getImm())) {
      // BT A.bit + AND A, #~bit.
      MIB = BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BTCLR_A_b))
                .add(firstMI.getOperand(0))
                .add(Byte);
    } else if ((Opc == RL78::BTF_mHL_b &&
                firstMI.getOpcode() == RL78::CLR1_mHL_b) ||
               (Opc == RL78::BTF_saddr_b &&
                firstMI.getOpcode() == RL78::CLR1_saddr_b) ||
               (Opc == RL78::BTF_sfr_b &&
                firstMI.getOpcode() == RL78::CLR1_sfr_b)) {
      // BT byte.bit + CLR1 byte.bit.
      if (!firstMI.getOperand(0).isIdenticalTo(Byte) ||
          firstMI.getOperand(1).getImm() != Bit.getImm())
        continue;
      unsigned NewOpc = Opc == RL78::BTF_mHL_b     ? RL78::BTCLR_mHL_b
                        : Opc == RL78::BTF_saddr_b ? RL78::BTCLR_saddr_b
                                                   : RL78::BTCLR_sfr_b;
      MIB = BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(NewOpc)).add(Byte);
    } else {
      continue;
    }
    MIB.add(Bit).add(MI.getOperand(2));
    MI.eraseFromParent();
    firstMI.eraseFromParent();
    Changed = true;
  }
  //
  return Changed;
}
