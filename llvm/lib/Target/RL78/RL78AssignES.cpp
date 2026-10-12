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
#include "llvm/ADT/SmallPtrSet.h"
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

/// The 8-bit register that is the low byte of the pair \p S on every path:
/// through INSERT_SUBREG, copies of the pair and PHIs (a far pointer that a
/// loop advances keeps its segment). No register if there is no single one.
/// \p Visited holds the PHIs on the way; a cycle back to one of them adds
/// nothing and is reported through \p Cycle.
static Register lowByteOfPair(Register S, const MachineRegisterInfo &MRI,
                              SmallPtrSetImpl<const MachineInstr *> &Visited,
                              bool &Cycle) {
  while (S.isVirtual()) {
    const MachineInstr *D = MRI.getUniqueVRegDef(S);
    if (!D)
      return Register();
    if (D->isInsertSubreg()) {
      if (D->getOperand(3).getImm() == RL78::sub_lo) {
        const MachineOperand &V = D->getOperand(2);
        return V.getSubReg() || !V.getReg().isVirtual() ? Register()
                                                         : V.getReg();
      }
      S = D->getOperand(1).getReg();
      continue;
    }
    if (D->isCopy() && !D->getOperand(1).getSubReg()) {
      S = D->getOperand(1).getReg();
      continue;
    }
    if (D->isPHI()) {
      if (!Visited.insert(D).second) {
        Cycle = true;
        return Register();
      }
      Register Common;
      for (unsigned I = 1, E = D->getNumOperands(); I != E; I += 2) {
        if (D->getOperand(I).getSubReg())
          return Register();
        bool Back = false;
        Register In =
            lowByteOfPair(D->getOperand(I).getReg(), MRI, Visited, Back);
        if (Back)
          continue;
        if (!In || (Common && In != Common))
          return Register();
        Common = In;
      }
      return Common;
    }
    return Register();
  }
  return Register();
}

/// The 8-bit register \p R is a copy of, through plain copies and through
/// the low byte of a pair (how selection hands over the segment byte of a
/// far pointer).
static Register traceByte(Register R, const MachineRegisterInfo &MRI) {
  while (true) {
    const MachineInstr *D = MRI.getUniqueVRegDef(R);
    if (!D || !D->isCopy() || !D->getOperand(1).getReg().isVirtual())
      return R;
    Register S = D->getOperand(1).getReg();
    unsigned Sub = D->getOperand(1).getSubReg();
    if (!Sub) {
      R = S;
      continue;
    }
    if (Sub != RL78::sub_lo)
      return R;
    SmallPtrSet<const MachineInstr *, 4> Visited;
    bool Cycle = false;
    Register Low = lowByteOfPair(S, MRI, Visited, Cycle);
    if (!Low)
      return R;
    R = Low;
  }
}

/// See runOnMachineFunction. Returns true if it rewrote the function.
static bool loadOnce(MachineFunction &MF) {
  MachineRegisterInfo &MRI = MF.getRegInfo();
  const TargetRegisterInfo *TRI = MF.getSubtarget().getRegisterInfo();
  const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();
  auto IsESValue = [&](const MachineOperand &MO) {
    return MO.isReg() && MO.getReg().isVirtual() &&
           MRI.getRegClass(MO.getReg()) == &RL78::RL78RegESRegClass;
  };

  // All loads must be MOV ES, A of one value or MOV ES, #byte of one byte.
  SmallVector<MachineInstr *, 8> Loads;
  Register Root;
  int64_t Imm = 0;
  for (MachineBasicBlock &MBB : MF)
    for (MachineInstr &MI : MBB) {
      if (MI.isDebugInstr())
        continue;
      if (MI.getNumOperands() && IsESValue(MI.getOperand(0)) &&
          MI.getOperand(0).isDef()) {
        if (!Loads.empty() && MI.getOpcode() != Loads.front()->getOpcode())
          return false;
        if (MI.getOpcode() == RL78::MOV_ES_A) {
          Register R = traceByte(MI.getOperand(1).getReg(), MRI);
          if (!Loads.empty() && R != Root)
            return false;
          Root = R;
        } else if (MI.getOpcode() == RL78::MOV_ES_i8 &&
                   MI.getOperand(1).isImm()) {
          if (!Loads.empty() && MI.getOperand(1).getImm() != Imm)
            return false;
          Imm = MI.getOperand(1).getImm();
        } else {
          return false;
        }
        Loads.push_back(&MI);
        continue;
      }
      if (MI.isCall() || MI.isInlineAsm() ||
          MI.modifiesRegister(RL78::ES, TRI))
        return false;
    }
  if (Loads.empty())
    return false;

  // Where the segment value is available: after the instruction that
  // defines it (after the PHIs and the copies of the incoming arguments),
  // or at the function's start for an immediate.
  MachineBasicBlock *Where = &MF.front();
  MachineBasicBlock::iterator At = Where->begin();
  if (Root) {
    MachineInstr *Def = MRI.getUniqueVRegDef(Root);
    if (!Def)
      return false;
    Where = Def->getParent();
    At = std::next(Def->getIterator());
  }
  At = Where->SkipPHIsAndLabels(At);
  while (At != Where->end() &&
         (At->isDebugInstr() ||
          (At->isCopy() && At->getOperand(1).getReg().isPhysical())))
    ++At;

  // MOV ES, A needs the value in A. Where it arrives there (the segment of
  // a far pointer that is the first argument) loading at once is free. For
  // a value elsewhere, a single load in the block that defines the value is
  // already as good where it is, at a point where A is free anyway.
  if (Root) {
    const MachineInstr *Def = MRI.getUniqueVRegDef(Root);
    bool ArrivesInA = Def->isCopy() && Def->getOperand(1).getReg() == RL78::R1;
    if (!ArrivesInA && Loads.size() == 1 &&
        Loads.front()->getParent() == Def->getParent())
      return false;
  }

  DebugLoc DL = Loads.front()->getDebugLoc();
  if (Root) {
    Register A = MRI.createVirtualRegister(&RL78::RL78ARegRegClass);
    BuildMI(*Where, At, DL, TII->get(TargetOpcode::COPY), A).addReg(Root);
    BuildMI(*Where, At, DL, TII->get(RL78::MOV_ES_A), RL78::ES).addReg(A);
    MRI.clearKillFlags(Root);
  } else {
    BuildMI(*Where, At, DL, TII->get(RL78::MOV_ES_i8), RL78::ES).addImm(Imm);
  }
  ++NumLoads;

  for (MachineInstr *Old : Loads) {
    Register V = Old->getOperand(0).getReg();
    for (MachineOperand &MO : make_early_inc_range(MRI.use_operands(V))) {
      if (MO.getParent()->isDebugInstr()) {
        MO.setReg(Register());
        continue;
      }
      MO.setReg(RL78::ES);
      MO.setIsKill(false);
    }
    Old->eraseFromParent();
    ++NumReused;
  }
  return true;
}

bool RL78AssignES::runOnMachineFunction(MachineFunction &MF) {
  MachineRegisterInfo &MRI = MF.getRegInfo();
  const TargetRegisterInfo *TRI = MF.getSubtarget().getRegisterInfo();
  bool Changed = false;
  SmallVector<MachineInstr *, 8> Loads;

  auto IsESValue = [&](const MachineOperand &MO) {
    return MO.isReg() && MO.getReg().isVirtual() &&
           MRI.getRegClass(MO.getReg()) == &RL78::RL78RegESRegClass;
  };

  // A function whose ES: accesses all use one segment value, and that has
  // nothing else that writes ES (no calls), loads ES once, where the value
  // is defined. Loading it at each user instead keeps the segment byte alive
  // across everything in between: it is spilled and reloaded, in a loop on
  // every iteration.
  if (loadOnce(MF))
    return true;

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
