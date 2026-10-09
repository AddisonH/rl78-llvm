//===-- RL78InsertInstsForDelayCycles.cpp - Implement __delay_cycles RL78 -===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass lower __delay_cycles pseudo instruction into NOP_cg like instructions
// to consume specified cycles.
// Note this pass must be placed as late as possible in pre-emit passes in order
// to avoid the inserted instructions to consume cycles are optimized away.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/RL78MCTargetDesc.h"
#include "RL78TargetMachine.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"

using namespace llvm;

namespace {
class RL78InsertInstsForDelayCycles : public MachineFunctionPass {
public:
  RL78InsertInstsForDelayCycles() : MachineFunctionPass(ID) {}
  StringRef getPassName() const override {
    return "RL78 Insert instructions for delay cycles";
  }

private:
  bool runOnMachineFunction(MachineFunction &MF) override;
  void processDelayCycleInst_1_4(MachineInstr &MI, const RL78InstrInfo &TII);
  void processDelayCycleInst_5(MachineInstr &MI, const RL78InstrInfo &TII);
  void processDelayCycleInst_6_1279(MachineInstr &MI, const RL78InstrInfo &TII);

private:
  static char ID;
};

char RL78InsertInstsForDelayCycles::ID = 0;
} // namespace

FunctionPass *llvm::createRL78InsertInstsForDelayCyclesPass() {
  return new RL78InsertInstsForDelayCycles();
}
void RL78InsertInstsForDelayCycles::processDelayCycleInst_1_4(
    MachineInstr &MI, const RL78InstrInfo &TII) {
  DebugLoc DL = MI.getDebugLoc();
  MachineBasicBlock &MBB = *MI.getParent();
  unsigned DelayCycles = MI.getOperand(0).getImm();
  switch (DelayCycles) {
  case 1: {
    // One NOP_cg instruction.
    BuildMI(MBB, MI, DL, TII.get(RL78::NOP_cg));
    break;
  }
  case 2: {
    // Two NOP_cg instructions.
    BuildMI(MBB, MI, DL, TII.get(RL78::NOP_cg));
    BuildMI(MBB, MI, DL, TII.get(RL78::NOP_cg));
    break;
  }
  case 3: {
    // Unconditional branch to next instruction.
    //    br #.NextMBB  ; 3 cycles
    //  .NextMBB:
    MachineBasicBlock *NextMBB = MBB.splitAt(MI);
    BuildMI(MBB, MI, DL, TII.get(RL78::BR_rel8_cg)).addMBB(NextMBB);
    break;
  }
  case 4: {
    // Unconditional branch to next instruction + One NOP_cg instruction.
    MachineBasicBlock *NextMBB = MBB.splitAt(MI);
    BuildMI(MBB, MI, DL, TII.get(RL78::NOP_cg));
    BuildMI(MBB, MI, DL, TII.get(RL78::BR_rel8_cg)).addMBB(NextMBB);
    break;
  }
  default: {
    llvm_unreachable("Delay cycles out of range for DELAY_CYCLES_1_4");
  }
  }
  // Erase the pseudo instruction.
  MI.eraseFromParent();
}

void RL78InsertInstsForDelayCycles::processDelayCycleInst_5(
    MachineInstr &MI, const RL78InstrInfo &TII) {
  DebugLoc DL = MI.getDebugLoc();
  MachineBasicBlock &MBB = *MI.getParent();
  // Cmp, conditional branch to next instruction.
  //    cmp0 a         ; 1 cycle
  //    bnc $.NextMBB ; 4 cycles (on condition taken)
  //  .NextMBB:
  MachineBasicBlock *NextMBB = MBB.splitAt(MI);
  BuildMI(MBB, MI, DL, TII.get(RL78::CMP0_r_cg)).addReg(RL78::R1);
  // The second operand is the condition code (an immediate, printed as "nc");
  // CY is read implicitly.
  BuildMI(MBB, MI, DL, TII.get(RL78::B_BNC))
      .addMBB(NextMBB)
      .addImm(RL78CC::RL78CC_NC)
      .addReg(RL78::CCreg, RegState::Implicit);
  // Erase the pseudo instruction.
  MI.eraseFromParent();
}

void RL78InsertInstsForDelayCycles::processDelayCycleInst_6_1279(
    MachineInstr &MI, const RL78InstrInfo &TII) {
  DebugLoc DL = MI.getDebugLoc();
  MachineBasicBlock &MBB = *MI.getParent();
  unsigned DelayCycles = MI.getOperand(0).getImm();
  unsigned AInit = (DelayCycles / 5 + 1) & 0xff;
  // Make loop that run <AInit> times.
  //     mov a, #<AInit>  ; 1 cycle
  //  .LoopMBB:           ; 5 cycle per loop
  //     dec a            ; | 1 cycle
  //     bnz $.LoopMBB    ; | 4 cycle (on condition taken)
  MBB.splitAt(MI);
  // Add DEC R1 at the end of MBB. This is later ater splitted into LoopBB.
  // This small hack is because splitAt method does not work on the end.
  // We stick to use splitAt method because we want automatic update of liveins.
  BuildMI(MBB, MBB.end(), DL, TII.get(RL78::DEC_r_cg)).addReg(RL78::R1);
  MachineBasicBlock *LoopBB = MBB.splitAt(MI);
  LoopBB->addSuccessor(LoopBB);
  BuildMI(MBB, MI, DL, TII.get(RL78::MOV_r_imm)).addReg(RL78::R1).addImm(AInit);
  BuildMI(*LoopBB, LoopBB->end(), DL, TII.get(RL78::B_BNZ))
      .addMBB(LoopBB)
      .addImm(RL78CC::RL78CC_NZ);
  // Erase the pseudo instruction.
  MI.eraseFromParent();
}

bool RL78InsertInstsForDelayCycles::runOnMachineFunction(MachineFunction &MF) {
  const RL78InstrInfo &TII = *MF.getSubtarget<RL78Subtarget>().getInstrInfo();
  bool Changed = false;
  SmallVector<MachineInstr *, 16> DelayCycleInsts_1_4;
  SmallVector<MachineInstr *, 16> DelayCycleInsts_5;
  SmallVector<MachineInstr *, 16> DelayCycleInsts_6_1279;
  for (auto &MBB : MF) {
    for (auto &MI : MBB) {
      if (MI.getOpcode() == RL78::DELAY_CYCLES_1_4) {
        DelayCycleInsts_1_4.push_back(&MI);
        Changed = true;
      }
      if (MI.getOpcode() == RL78::DELAY_CYCLES_5) {
        DelayCycleInsts_5.push_back(&MI);
        Changed = true;
      }
      if (MI.getOpcode() == RL78::DELAY_CYCLES_6_1279) {
        DelayCycleInsts_6_1279.push_back(&MI);
        Changed = true;
      }
    }
  }
  for (auto *MI : DelayCycleInsts_1_4) {
    processDelayCycleInst_1_4(*MI, TII);
  }
  for (auto *MI : DelayCycleInsts_5) {
    processDelayCycleInst_5(*MI, TII);
  }
  for (auto *MI : DelayCycleInsts_6_1279) {
    processDelayCycleInst_6_1279(*MI, TII);
  }
  return Changed;
}
