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
    // if BT.
    if (((MI.getOpcode() == RL78::BTBF_A) ||
         (MI.getOpcode() == RL78::BTBF_memr) ||
         (MI.getOpcode() == RL78::BTBF_saddr) ||
         (MI.getOpcode() == RL78::BTBF_sfri_addr)) &&
        (MI.getOperand(1).getImm() == RL78CC::RL78CC_Z)) {
      MachineBasicBlock *TBB = MI.getOperand(0).getMBB();
      if (!TBB)
        continue;

      MachineInstr &firstMI = *TBB->getFirstNonDebugInstr();
      //
      if ((firstMI.getOpcode() == RL78::AND_r_imm) &&
          (firstMI.getOperand(0).getReg() == MI.getOperand(2).getReg())) {
        int bitPos = MI.getOperand(3).getImm();
        int andMask = firstMI.getOperand(2).getImm();
        if (andMask == ~(1 << bitPos)) {
          // Replace the BT A.bit + AND with a BTCLR.
          BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BTCLR_A))
              .add(firstMI.getOperand(0))
              .add(MI.getOperand(0))
              .add(MI.getOperand(1))
              .add(MI.getOperand(2))
              .add(MI.getOperand(3));
          MI.eraseFromParent();
          firstMI.eraseFromParent();
          Changed = true;
        }
      } else if ((firstMI.getOpcode() == RL78::CLR1_memr) &&
                 (firstMI.getOperand(0).getReg() ==
                  MI.getOperand(2).getReg()) &&
                 (firstMI.getOperand(1).getImm() ==
                  MI.getOperand(3).getImm())) {
        // Replace the BT [HL].bit + CLR1 [HL].bit with a BTCLR.
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BTCLR_memr))
            .add(MI.getOperand(0))
            .add(MI.getOperand(1))
            .add(MI.getOperand(2))
            .add(MI.getOperand(3));
        MI.eraseFromParent();
        firstMI.eraseFromParent();
        Changed = true;
      } else if ((firstMI.getOpcode() == RL78::CLR1_saddr) &&
                 (firstMI.getOperand(1).getImm() ==
                  MI.getOperand(3).getImm())) {
        // Replace the BT saddr.bit + CLR1 saddr.bit with a BTCLR.
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BTCLR_saddr))
            .add(MI.getOperand(0))
            .add(MI.getOperand(1))
            .add(MI.getOperand(2))
            .add(MI.getOperand(3));
        MI.eraseFromParent();
        firstMI.eraseFromParent();
        Changed = true;
      } else if ((firstMI.getOpcode() == RL78::CLR1_sfr) &&
                 (firstMI.getOperand(0).getImm() ==
                  MI.getOperand(2).getImm()) &&
                 (firstMI.getOperand(1).getImm() ==
                  MI.getOperand(3).getImm())) {
        // Replace the BT sfr.bit + CLR1 sfr.bit with a BTCLR.
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BTCLR_sfri_addr))
            .add(MI.getOperand(0))
            .add(MI.getOperand(2))
            .add(MI.getOperand(3));
        MI.eraseFromParent();
        firstMI.eraseFromParent();
        Changed = true;
      }
    }
  }
  //
  return Changed;
}
