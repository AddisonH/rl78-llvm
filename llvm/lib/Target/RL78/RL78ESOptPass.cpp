//===------------------ RL78ESOptPass.cpp -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
// Pass to eliminate unnecessary re-initializations of the ES register.
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78Subtarget.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"

#include <optional>
#include <tuple>

using namespace llvm;

namespace {
class RL78ESOptPass : public MachineFunctionPass {
public:
  RL78ESOptPass() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 ES register optimization";
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  static char ID;
};

char RL78ESOptPass::ID = 0;
} // end anonymous namespace

FunctionPass *llvm::createRL78ESOptPass() { return new RL78ESOptPass(); }

// What a MOV es, a or MOV es, #imm puts in ES: the immediate, or the virtual
// register (and subregister) the A operand was copied from.
using ESValue = std::tuple<bool, Register, unsigned, int64_t>;

static std::optional<ESValue> getESValue(const MachineInstr &MI,
                                         const MachineRegisterInfo &MRI) {
  if (MI.getOpcode() == RL78::MOV_es_imm) {
    if (!MI.getOperand(1).isImm())
      return std::nullopt;
    return ESValue(true, Register(), 0, MI.getOperand(1).getImm());
  }
  if (MI.getOpcode() != RL78::MOV_es_A)
    return std::nullopt;
  Register Reg = MI.getOperand(1).getReg();
  unsigned Sub = MI.getOperand(1).getSubReg();
  const MachineInstr *Def = nullptr;
  if (Reg.isVirtual())
    Def = MRI.getUniqueVRegDef(Reg);
  else if (MI.getIterator() != MI.getParent()->begin())
    Def = &*std::prev(MI.getIterator()); // $r1 = COPY ... at -O0
  if (!Def || !Def->isCopy() || Def->getOperand(0).getReg() != Reg)
    return Reg.isVirtual() ? std::optional(ESValue(false, Reg, Sub, 0))
                           : std::nullopt;
  Reg = Def->getOperand(1).getReg();
  Sub = Def->getOperand(1).getSubReg();
  // Values in virtual registers do not change (SSA); physical ones may.
  if (!Reg.isVirtual())
    return std::nullopt;
  return ESValue(false, Reg, Sub, 0);
}

// Deletes a write of ES that writes the value ES already has: LowerESSrc sets
// ES before every far access, which repeats the same MOV es, a (and the copy
// to A feeding it) for consecutive accesses through one far pointer:
//   mov a, c
//   mov es, a
//   movw es:[hl+4], ax
//   mov a, c      <- not needed
//   mov es, a     <- not needed
//   movw es:[hl+6], ax
bool RL78ESOptPass::runOnMachineFunction(MachineFunction &MF) {
  MachineRegisterInfo &MRI = MF.getRegInfo();
  const TargetRegisterInfo *TRI = MF.getSubtarget().getRegisterInfo();
  if (!MRI.isSSA())
    return false;
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    std::optional<ESValue> Current;
    for (MachineInstr &MI : llvm::make_early_inc_range(MBB)) {
      std::optional<ESValue> V = getESValue(MI, MRI);
      if (V && Current && *V == *Current) {
        // The copy into A feeding MOV es, a.
        MachineInstr *Copy = nullptr;
        if (MI.getOpcode() == RL78::MOV_es_A) {
          Register A = MI.getOperand(1).getReg();
          if (A.isVirtual()) {
            if (MRI.hasOneNonDBGUse(A))
              Copy = MRI.getUniqueVRegDef(A);
          } else if (MI.getOperand(1).isKill()) {
            Copy = &*std::prev(MI.getIterator());
          }
        }
        MI.eraseFromParent();
        if (Copy && Copy->isCopy())
          Copy->eraseFromParent();
        Changed = true;
        continue;
      }
      if (V)
        Current = V;
      else if (MI.isCall() || MI.isInlineAsm() ||
               MI.modifiesRegister(RL78::ES, TRI))
        Current = std::nullopt;
    }
  }
  return Changed;
}
