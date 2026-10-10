//===-- RL78AssignES.cpp - Load ES before the instructions that use it ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// An instruction with the ES: prefix has ES as an operand. Instruction
// selection gives it the result of the MOV ES, #byte / MOV ES, A / MOV ES,
// saddr that loads the segment, a virtual register of the class that holds
// only ES:
//
//   %es:rl78reges = MOV_ES_i8 15
//   %a:rl78areg = MOV_A_emRP %es, %hl
//
// ES is not allocated: it is loaded where it is needed. Right after
// selection, while each such value is still used in the block that defines
// it, this pass puts the load in ES itself before each user, unless ES still
// holds that value:
//
//   $es = MOV_ES_i8 15
//   %a:rl78areg = MOV_A_emRP $es, %hl
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78Subtarget.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"

#define DEBUG_TYPE "rl78-assign-es"
using namespace llvm;

STATISTIC(NumLoads, "Number of ES loads placed");
STATISTIC(NumReused, "Number of ES loads not needed");

namespace {
class RL78AssignES : public MachineFunctionPass {
public:
  static char ID;
  RL78AssignES() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override { return "RL78 load ES for its users"; }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;
};
} // end anonymous namespace

char RL78AssignES::ID = 0;

FunctionPass *llvm::createRL78AssignESPass() { return new RL78AssignES(); }

bool RL78AssignES::runOnMachineFunction(MachineFunction &MF) {
  MachineRegisterInfo &MRI = MF.getRegInfo();
  const TargetRegisterInfo *TRI = MF.getSubtarget().getRegisterInfo();
  bool Changed = false;
  SmallVector<MachineInstr *, 8> Loads;

  auto IsESValue = [&](const MachineOperand &MO) {
    return MO.isReg() && MO.getReg().isVirtual() &&
           MRI.getRegClass(MO.getReg()) == &RL78::RL78RegESRegClass;
  };

  for (MachineBasicBlock &MBB : MF) {
    // The value ES holds, if it is one of these.
    Register Current;
    for (MachineInstr &MI : MBB) {
      if (MI.isDebugInstr())
        continue;
      if (MI.getNumOperands() && IsESValue(MI.getOperand(0)) &&
          MI.getOperand(0).isDef()) {
        Loads.push_back(&MI);
        continue;
      }
      bool Uses = false;
      for (MachineOperand &MO : MI.uses()) {
        if (!IsESValue(MO))
          continue;
        Register V = MO.getReg();
        if (V != Current) {
          MachineInstr *Load = MRI.getUniqueVRegDef(V);
          assert(Load && Load->getParent() == &MBB &&
                 "ES value used outside the block that loads it");
          MachineInstr *Copy = MF.CloneMachineInstr(Load);
          Copy->getOperand(0).setReg(RL78::ES);
          for (MachineOperand &Src : Copy->uses())
            if (Src.isReg())
              Src.setIsKill(false);
          MBB.insert(MI.getIterator(), Copy);
          MRI.clearKillFlags(V);
          for (const MachineOperand &Src : Load->uses())
            if (Src.isReg() && Src.getReg().isVirtual())
              MRI.clearKillFlags(Src.getReg());
          Current = V;
          ++NumLoads;
        } else {
          ++NumReused;
        }
        MO.setReg(RL78::ES);
        MO.setIsKill(false);
        Uses = true;
        Changed = true;
      }
      // Anything else that may write ES.
      if (!Uses && (MI.isCall() || MI.isInlineAsm() ||
                    MI.modifiesRegister(RL78::ES, TRI)))
        Current = Register();
    }
  }
  for (MachineInstr *Load : Loads) {
    assert(MRI.use_nodbg_empty(Load->getOperand(0).getReg()) &&
           "ES value still in use");
    Load->eraseFromParent();
    Changed = true;
  }
  return Changed;
}
