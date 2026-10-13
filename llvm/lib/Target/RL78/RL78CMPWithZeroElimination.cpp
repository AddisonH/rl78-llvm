//===-- RL78CMPWithZeroElimination.cpp - Define TargetMachine for RL78 ---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78Subtarget.h"
#include "llvm/CodeGen/LivePhysRegs.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "RL78CMPWithZeroElimPass"
using namespace llvm;

namespace {
class RL78CMPWithZeroElimPass : public MachineFunctionPass {
public:
  explicit RL78CMPWithZeroElimPass(bool Late = false)
      : MachineFunctionPass(ID), Late(Late) {}

  StringRef getPassName() const override {
    return "RL78 CMP with 0 elimination";
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  static char ID;
  // The last run, when no later pass moves values through AX any more.
  bool Late;
};

char RL78CMPWithZeroElimPass::ID = 0;
} // end anonymous namespace

FunctionPass *llvm::createRL78CMPWithZeroElimPass(bool Late) {
  return new RL78CMPWithZeroElimPass(Late);
}

// True if only the Z flag of the flags \p CMP sets is read.
static bool onlyZeroFlagRead(MachineBasicBlock &MBB, MachineInstr &CMP,
                             const TargetRegisterInfo *TRI) {
  for (MachineBasicBlock::iterator I = std::next(CMP.getIterator()),
                                   E = MBB.end();
       I != E; ++I) {
    if (I->isDebugInstr())
      continue;
    if (I->readsRegister(RL78::CCreg, TRI)) {
      unsigned CCIdx;
      if (I->getOpcode() == RL78::BRCC)
        CCIdx = 1;
      else if (I->getOpcode() == RL78::SKcc)
        CCIdx = 0;
      else
        return false;
      int64_t CC = I->getOperand(CCIdx).getImm();
      if (CC != RL78CC::RL78CC_Z && CC != RL78CC::RL78CC_NZ)
        return false;
    }
    if (I->modifiesRegister(RL78::CCreg, TRI))
      return true;
  }
  return none_of(MBB.successors(), [](const MachineBasicBlock *Succ) {
    return Succ->isLiveIn(RL78::CCreg);
  });
}

// CMPW AX, #0 is 3 bytes. Two shorter ways to the same flags:
//
//   or a, x              2 bytes; Z as from the comparison, A is lost
//   clrw bc; cmpw ax, bc 2 bytes, 2 instructions; all flags, BC is lost
//
// The second only where size counts more than the extra instruction.
static bool shortenCMPWWithZero(MachineBasicBlock &MBB) {
  MachineFunction &MF = *MBB.getParent();
  if (!MF.getProperties().hasTracksLiveness())
    return false;
  const TargetRegisterInfo *TRI = MF.getSubtarget().getRegisterInfo();
  const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();

  SmallVector<MachineInstr *, 4> CMPs;
  for (MachineInstr &MI : MBB)
    if (MI.getOpcode() == RL78::CMPW_AX_i16 && MI.getOperand(1).isImm() &&
        MI.getOperand(1).getImm() == 0)
      CMPs.push_back(&MI);

  bool Changed = false;
  for (MachineInstr *CMP : CMPs) {
    // What is live after the comparison, which defines no register.
    LivePhysRegs Live(*TRI);
    Live.addLiveOuts(MBB);
    for (MachineInstr &I : llvm::reverse(MBB)) {
      if (&I == CMP)
        break;
      Live.stepBackward(I);
    }
    auto IsFree = [&](MCRegister Reg) {
      for (MCRegAliasIterator AI(Reg, TRI, true); AI.isValid(); ++AI)
        if (Live.contains(*AI))
          return false;
      return true;
    };

    const DebugLoc &DL = CMP->getDebugLoc();
    if (IsFree(RL78::R1) && onlyZeroFlagRead(MBB, *CMP, TRI)) {
      BuildMI(MBB, CMP, DL, TII->get(RL78::OR_A_r))
          .addReg(RL78::R1, RegState::Define | RegState::Dead)
          .addReg(RL78::R1, RegState::Kill)
          .addReg(RL78::R0);
    } else if (MF.getFunction().hasOptSize() && IsFree(RL78::RP2)) {
      BuildMI(MBB, CMP, DL, TII->get(RL78::CLRW_rp), RL78::RP2);
      BuildMI(MBB, CMP, DL, TII->get(RL78::CMPW_AX_rp))
          .addReg(RL78::RP0)
          .addReg(RL78::RP2, RegState::Kill);
    } else {
      continue;
    }
    CMP->eraseFromParent();
    Changed = true;
  }
  return Changed;
}

// INC r or DEC r, then instructions that have nothing to do with r, then
// CMP0 r and a branch on Z:
//
//     dec c; addw ax, [hl]; incw hl; cmp0 c; bnz $loop
//
// INC and DEC set Z themselves. Move the INC or DEC down to the comparison
// and drop the comparison; what was between them did not read the flags it
// set (they were dead) and does not see the register.
static bool sinkIncDecToCompare(MachineBasicBlock &MBB) {
  MachineFunction &MF = *MBB.getParent();
  if (MF.getRegInfo().isSSA())
    return false;
  const TargetRegisterInfo *TRI = MF.getSubtarget().getRegisterInfo();
  MachineBasicBlock::iterator Br = MBB.getFirstTerminator();
  if (Br == MBB.end() || Br == MBB.begin() || Br->getOpcode() != RL78::BRCC)
    return false;
  MachineBasicBlock::iterator Cmp = prev_nodbg(Br, MBB.begin());
  if (Cmp == Br || Cmp->getOpcode() != RL78::CMP0_r ||
      !Cmp->getOperand(0).getReg().isPhysical() ||
      !onlyZeroFlagRead(MBB, *Cmp, TRI))
    return false;
  Register Reg = Cmp->getOperand(0).getReg();
  for (MachineBasicBlock::iterator I = Cmp; I != MBB.begin();) {
    --I;
    if (I->isDebugInstr())
      continue;
    if ((I->getOpcode() == RL78::DEC_r || I->getOpcode() == RL78::INC_r) &&
        I->getOperand(0).getReg() == Reg) {
      if (!I->registerDefIsDead(RL78::CCreg, TRI))
        return false;
      if (std::next(I) != Cmp)
        MBB.splice(Cmp, &MBB, I);
      for (MachineOperand &MO : I->implicit_operands())
        if (MO.isDef() && MO.getReg() == RL78::CCreg)
          MO.setIsDead(false);
      Cmp->eraseFromParent();
      return true;
    }
    if (I->isCall() || I->readsRegister(Reg, TRI) ||
        I->modifiesRegister(Reg, TRI))
      return false;
  }
  return false;
}

static bool definesCCReg(MachineInstr &MI, bool requiresZflag) {
  bool hasdefCCReg = false;
  bool hasdefZflag = false;
  for (unsigned i = MI.getNumExplicitOperands(), e = MI.getNumOperands();
       i != e; ++i) {
    if (MI.getOperand(i).isReg() && (MI.getOperand(i).getReg() == RL78::CCreg))
      hasdefCCReg = MI.getOperand(i).isDef();
    else if (MI.getOperand(i).isReg() &&
             (MI.getOperand(i).getReg() == RL78::Zflag))
      hasdefZflag = MI.getOperand(i).isDef();
  }
  return (requiresZflag) ? hasdefCCReg && hasdefZflag : hasdefCCReg;
}

static void updateCCRegFlag(MachineInstr &MI) {
  for (unsigned i = MI.getNumExplicitOperands(), e = MI.getNumOperands();
       i != e; ++i) {
    if (MI.getOperand(i).isReg() &&
        (MI.getOperand(i).getReg() == RL78::CCreg)) {
      MI.getOperand(i).setIsDead(false);
      break;
    }
  }
}

// TODO: split this function into 2 functions
bool RL78CMPWithZeroElimPass::runOnMachineFunction(MachineFunction &MF) {
  bool Changed = false;
  //
  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;
    //
    if (MBB.getLastNonDebugInstr() == MBB.end())
      continue;
    Changed |= sinkIncDecToCompare(MBB);
    // MBB.dump();
    for (MachineBasicBlock::reverse_iterator prevI = MBB.rbegin(),
                                             e = MBB.rend();
         prevI != e; ++prevI) {
      // prevI->dump();
      // If conditional branch
      if (prevI->getOpcode() == RL78::BRCC) {
        // We can only remove the compare instruction in case of "!= 0" and "==
        // 0" operations.
        assert(prevI->getOperand(1).isImm() &&
               "Invalid BRCC instruction operand(2)!");
        RL78CC::CondCodes targetCC =
            static_cast<RL78CC::CondCodes>(prevI->getOperand(1).getImm());
        if ((targetCC != RL78CC::RL78CC_NZ) && (targetCC != RL78CC::RL78CC_Z))
          break;
        ++prevI;
        while (prevI != MBB.rend()) {
          if (definesCCReg(*prevI, false))
            break;
          ++prevI;
        }
        // Sometimes blocks get merged and the CMP instruction gets placed in
        // another MBB, so we should give up trying to optimize this.
        if (prevI == MBB.rend())
          break;
        // If compare with 0 instruction.
        // We don't check for CMP0_abs16_cg because it's highly unlikely to happen:
        // We will not have a store and a load (maybe in case of volatile in
        // which case we don't realy want to touch it) normally the compiler
        // will do a store and a compare using the same registers (which
        // contains the store value) as operand 0. We also ignore any signed
        // comparisons which needed extra instruction (XOR1_cy_r etc.), see
        // RL78TargetLowering::LowerSignedCMP.
        if ((prevI->getOpcode() == RL78::CMP0_r) ||
            ((prevI->getOpcode() == RL78::CMPW_AX_i16) &&
             (prevI->getOperand(1).getImm() == 0))) {
          MachineInstr &CMPI = *prevI;
          ++prevI;
          while (prevI != MBB.rend()) {
            MachineInstr &PrevMI = *prevI;
            // Don't go past function calls.
            if (PrevMI.isCall())
              break;
            // PrevMI.dump();
            // XCH(W) have 2 dst registers but doesn't update CCReg
            // so we need to make sure the second dst reg is not writing
            // the register in question.
            if ((PrevMI.getNumOperands() > 1) && PrevMI.getOperand(1).isReg() &&
                PrevMI.getOperand(1).isDef() &&
                (PrevMI.getOperand(1).getReg() ==
                 CMPI.getOperand(0).getReg())) {
              break;
            }
            // If we have a reg def.
            if ((PrevMI.getNumOperands() > 0) && PrevMI.getOperand(0).isReg() &&
                PrevMI.getOperand(0).isDef()) {
              const TargetRegisterInfo *TRI =
                  MF.getSubtarget<RL78Subtarget>().getRegisterInfo();
              // if PrevMI defines a subreg of CMPI's dest reg
              // we can't do anything.
              if (TRI->isSubRegister(CMPI.getOperand(0).getReg(),
                                     PrevMI.getOperand(0).getReg()))
                break;
              // If PrevMI defines the register used by the CMPI.
              if (PrevMI.getOperand(0).getReg() ==
                  CMPI.getOperand(0).getReg()) {
                if (definesCCReg(PrevMI, true)) {
                  // the CC reg of this instruction is
                  // marked as dead we need to update this.
                  updateCCRegFlag(PrevMI);
                  // Erase CMP instruction.
                  CMPI.eraseFromParent();
                  Changed = true;
                }
                break;
              }
            }
            ++prevI;
          }
        }
        break;
      }
    }
    
    SmallVector<MachineInstr*, 4> InstToKill;
    for (MachineBasicBlock::reverse_iterator prevI = MBB.rbegin(),
                                             e = MBB.rend();
         prevI != e; ++prevI) {
      if (prevI->getOpcode() == RL78::BRCC) {
        MachineInstr &BRCC = *prevI;
        RL78CC::CondCodes targetCC =
            static_cast<RL78CC::CondCodes>(BRCC.getOperand(1).getImm());
        if ((targetCC != RL78CC::RL78CC_NZ) && (targetCC != RL78CC::RL78CC_Z))
          break;
        do {
          prevI++;
        } while (prevI != MBB.rend() && prevI->isDebugInstr());

        if (prevI == MBB.rend())
          break;

        // Optimize compare with 0xFF to INC
        if (prevI != MBB.rend() && prevI->getOpcode() == RL78::CMP_A_i8 &&
            prevI->getOperand(1).getImm() == -1 &&
            prevI->getOperand(0).isKill()) {
            const TargetInstrInfo *TII = MBB.getParent()->getSubtarget<RL78Subtarget>().getInstrInfo();
            // INC r writes r, which the CMP left dead: only Z is wanted.
            Register R = prevI->getOperand(0).getReg();
            BuildMI(MBB, prevI.getReverse(), prevI->getDebugLoc(),
                    TII->get(RL78::INC_r))
                .addReg(R, RegState::Define | RegState::Dead)
                .addReg(R, RegState::Kill);
            BuildMI(MBB, BRCC, BRCC.getDebugLoc(),
                  TII->get(RL78::BRCC))
              .add(BRCC.getOperand(0))
              .addImm(targetCC);
            InstToKill.push_back(&*prevI);
            InstToKill.push_back(&BRCC);
        }
      }
    }

    for (MachineInstr *Inst : InstToKill) {
      LLVM_DEBUG(dbgs() << "erasing instruction: ");
      LLVM_DEBUG(Inst->dump());
      Inst->eraseFromParent();
      Changed = true;
    }

    if (Late)
      Changed |= shortenCMPWWithZero(MBB);
  }
  return Changed;
}
