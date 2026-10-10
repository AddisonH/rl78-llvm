//===-- RL78SplitConstrainedValues.cpp - Shorten constrained live ranges --===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Most RL78 instructions take an operand in one particular register: A, AX,
// HL, B or C. Instruction selection gives the virtual register an instruction
// defines the class of that operand, so the result of
//
//   %a:rl78areg = ADD_A_r %b, %c
//
// can only ever be in A, however long it lives and whatever reads it. The
// allocator cannot keep two such values at once, and a reload of a spilled
// one needs A even where the reader does not (and where A may be taken by an
// argument register).
//
// Give each such value a copy in an unconstrained register right after its
// definition, and let every reader that needs a particular register take its
// own copy:
//
//   %a:rl78areg = ADD_A_r %b, %c
//   %v:rl78reg = COPY %a
//   ...
//   %t:rl78areg = COPY %v
//   MOV_mHL_A %hl, %t
//
// The constrained ranges are then as short as they can be. The coalescer
// joins the copies again where the register is free for the whole range
// (RL78RegisterInfo::shouldCoalesce).
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78Subtarget.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetInstrInfo.h"
#include "llvm/CodeGen/TargetRegisterInfo.h"

#define DEBUG_TYPE "rl78-split-constrained"
using namespace llvm;

STATISTIC(NumSplit, "Number of constrained values copied out");
STATISTIC(NumUseCopies, "Number of copies made for constrained operands");

namespace {
class RL78SplitConstrainedValues : public MachineFunctionPass {
public:
  static char ID;
  RL78SplitConstrainedValues() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 shorten the live ranges of constrained values";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;
};
} // end anonymous namespace

char RL78SplitConstrainedValues::ID = 0;

FunctionPass *llvm::createRL78SplitConstrainedValuesPass() {
  return new RL78SplitConstrainedValues();
}

bool RL78SplitConstrainedValues::runOnMachineFunction(MachineFunction &MF) {
  MachineRegisterInfo &MRI = MF.getRegInfo();
  if (!MRI.isSSA())
    return false;
  const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();
  const TargetRegisterInfo *TRI = MF.getSubtarget().getRegisterInfo();
  bool Changed = false;

  // The class operand OpNo of MI needs its (sub)register in, if any.
  auto Constraint = [&](const MachineOperand &MO) {
    const MachineInstr &MI = *MO.getParent();
    return MI.getRegClassConstraint(MO.getOperandNo(), TII, TRI);
  };

  for (unsigned I = 0, E = MRI.getNumVirtRegs(); I != E; ++I) {
    Register V = Register::index2VirtReg(I);
    const TargetRegisterClass *RC = MRI.getRegClassOrNull(V);
    if (!RC)
      continue;
    if (!static_cast<const RL78RegisterInfo *>(TRI)->isSmallClass(RC))
      continue;
    const TargetRegisterClass *Wide = TRI->getLargestLegalSuperClass(RC, MF);
    MachineInstr *Def = MRI.getUniqueVRegDef(V);
    if (!Def || MRI.use_nodbg_empty(V))
      continue;

    // Does the defining instruction need the class, or did the value get it
    // from a reader (a copy, a PHI, an instruction that writes any register)?
    const TargetRegisterClass *DC =
        Def->getRegClassConstraint(Def->findRegisterDefOperandIdx(V, TRI), TII,
                                   TRI);
    bool DefNeedsClass = DC && !DC->hasSubClassEq(Wide);

    // Already as short as it gets: the copy made for the operand of the next
    // instruction, or a result whose only reader is the copy out after it.
    if (MRI.hasOneNonDBGUse(V)) {
      MachineOperand &MO = *MRI.use_nodbg_begin(V);
      MachineInstr &Use = *MO.getParent();
      bool Adjacent = Use.getParent() == Def->getParent() &&
                      std::next(Def->getIterator()) == Use.getIterator();
      const TargetRegisterClass *UC = Constraint(MO);
      if (Adjacent && Def->isCopy() && UC && !MO.getSubReg() &&
          !UC->hasSubClassEq(Wide))
        continue;
      if (Adjacent && DefNeedsClass && Use.isCopy() &&
          !Use.getOperand(1).getSubReg() &&
          Use.getOperand(0).getReg().isVirtual() &&
          MRI.getRegClass(Use.getOperand(0).getReg()) == Wide)
        continue;
    }

    SmallVector<MachineOperand *, 8> Uses;
    for (MachineOperand &MO : MRI.use_operands(V))
      Uses.push_back(&MO);

    // The value itself may be anywhere unless its definition needs the
    // class; then it is copied out, and the copies for the readers follow.
    Register W = V;
    if (!DefNeedsClass) {
      MRI.setRegClass(V, Wide);
    } else {
      W = MRI.createVirtualRegister(Wide);
      MachineBasicBlock &MBB = *Def->getParent();
      MachineBasicBlock::iterator At =
          Def->isPHI() ? MBB.getFirstNonPHI() : std::next(Def->getIterator());
      BuildMI(MBB, At, Def->getDebugLoc(), TII->get(TargetOpcode::COPY), W)
          .addReg(V);
    }
    for (MachineOperand *MO : Uses) {
      MachineInstr &MI = *MO->getParent();
      MO->setIsKill(false);
      const TargetRegisterClass *UC = MI.isDebugInstr() ? nullptr : Constraint(*MO);
      unsigned Sub = MO->getSubReg();
      bool Fits = !UC ||
                  (Sub ? TRI->getMatchingSuperRegClass(Wide, UC, Sub) == Wide
                       : UC->hasSubClassEq(Wide));
      if (Fits) {
        MO->setReg(W);
        continue;
      }
      // PHI operands are never constrained, so MI is in the block proper.
      const TargetRegisterClass *TC = Sub ? UC : TRI->getCommonSubClass(UC, Wide);
      assert(TC && "operand class has no register the value can be in");
      Register T = MRI.createVirtualRegister(TC);
      BuildMI(*MI.getParent(), MI, MI.getDebugLoc(),
              TII->get(TargetOpcode::COPY), T)
          .addReg(W, {}, Sub);
      MO->setReg(T);
      MO->setSubReg(0);
      ++NumUseCopies;
    }
    ++NumSplit;
    Changed = true;
  }
  return Changed;
}
