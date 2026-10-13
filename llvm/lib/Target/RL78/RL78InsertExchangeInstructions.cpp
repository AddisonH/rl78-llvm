//===- RL78InsertExchangeInstructions.cpp - Define TargetMachine for RL78 -===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
//
//===----------------------------------------------------------------------===//
// TODO: Revisit this whole file, maybe move some of xch to ISelLowering
#include "RL78TargetMachine.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/LivePhysRegs.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/PseudoSourceValue.h"

using namespace llvm;

#define DEBUG_TYPE "insert-exchange"

static cl::opt<bool> RL78AccumSched(
    "rl78-accum-sched", cl::Hidden, cl::init(true),
    cl::desc("Move stack-slot loads to where AX is dead before inserting "
             "exchanges"));

namespace {
class RL78InsertExchangeInstructionsPass : public MachineFunctionPass {
public:
  RL78InsertExchangeInstructionsPass() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 insert exchange instructions";
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

  static char ID;
};

char RL78InsertExchangeInstructionsPass::ID = 0;
} // end anonymous namespace

FunctionPass *llvm::createRL78InsertExchangeInstructionsPass() {
  return new RL78InsertExchangeInstructionsPass();
}

namespace llvm {
void initializeRL78InsertExchangeInstructionsPassPass(PassRegistry &);
}

// The instructions selected or built with a register operand have it in a
// register the instruction encodes. Only the pseudos of the allocator's
// spill code (TargetInstrInfo::storeRegToStackSlot/loadRegFromStackSlot)
// take any register: they are MOV/MOVW with [SP+byte] through A/AX, with the
// register moved or exchanged in and out here.
static void insert8BitExchange(MachineInstr &MI, unsigned opIndex, DebugLoc &DL,
                               MachineBasicBlock &MBB,
                               const TargetInstrInfo *TII, bool isALive) {
  MachineOperand &MO = MI.getOperand(opIndex);
  Register Reg = MO.getReg();
  bool IsDef = MO.isDef();
  if (Reg == RL78::R1)
    return;
  if (!isALive && !IsDef) {
    // MOV leaves the source intact.
    BuildMI(MBB, MI, DL, TII->get(RL78::MOV_A_r), RL78::R1)
        .addReg(Reg, getKillRegState(MO.isKill()));
  } else if (!isALive) {
    BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(RL78::MOV_r_A), Reg)
        .addReg(RL78::R1, RegState::Kill);
  } else {
    // xch A, r
    // mov A, [SP+byte] / mov [SP+byte], A
    // xch A, r
    unsigned Xch = RL78InstrInfo::getXCHOpcode(Reg);
    BuildMI(MBB, MI, DL, TII->get(Xch), RL78::R1)
        .addReg(Reg, RegState::Define)
        .addReg(RL78::R1, RegState::Kill)
        .addReg(Reg, RegState::Kill);
    BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(Xch), RL78::R1)
        .addReg(Reg, RegState::Define)
        .addReg(RL78::R1, RegState::Kill)
        .addReg(Reg, RegState::Kill);
  }
  MO.ChangeToRegister(RL78::R1, IsDef);
}

// if operand(opIndex) is NOT A register (and it needs to be) we need to
// exchange the value to A and back in other words generate the following
// sequence: xchw AX, RPx// if operand(opIndex) is NOT A register (and it needs to be) we need to
// exchange the value to A and back in other words generate the following
// sequence: xchw AX, RPx op AX, <...> xchw AX, RPx
// Returns false if MI was replaced.
static bool insert16BitExchange(MachineInstr &MI, unsigned opIndex,
                                DebugLoc &DL, MachineBasicBlock &MBB,
                                const TargetInstrInfo *TII, bool isAXLive) {
  // MBB.dump();
  // MI.dump();

  unsigned Reg = MI.getOperand(opIndex).getReg();
  bool IsDef = MI.getOperand(opIndex).isDef();
  bool IsTied = MI.getOperand(opIndex).isTied();
  // if dest is NOT A register we need to exchange the value to A and back
  if (Reg != RL78::RP0) {
    // Pure use and AX dead: copying in is enough, and MOVW leaves Reg intact.
    if ((!isAXLive) && !IsDef) {
      TII->copyPhysReg(MBB, MI, DL, RL78::RP0, Reg,
                       MI.getOperand(opIndex).isKill());
    }
    // Pure def and AX dead: copy out only. A tied operand is also read, so it
    // falls through to the exchange below.
    else if ((!isAXLive) && IsDef && !IsTied) {
      TII->copyPhysReg(MBB, std::next(MI.getIterator()), DL, Reg, RL78::RP0,
                       true);
    } else {
      // generate the following sequence:
      // xchw AX, Rx
      // op AX, <...>
      // xchw A, Rx
      if (!MBB.getParent()->getRegInfo().isReserved(Reg) &&
          Reg != RL78::MACRH && Reg != RL78::MACRL) {
        BuildMI(MBB, MI, DL, TII->get(RL78::XCHW_AX_rp), RL78::RP0)
            .addReg(Reg, RegState::Define)
            .addReg(RL78::RP0, RegState::Kill)
            .addReg(Reg, RegState::Kill);
        BuildMI(MBB, std::next(MI.getIterator()), DL,
                TII->get(RL78::XCHW_AX_rp), RL78::RP0)
            .addReg(Reg, RegState::Define)
            .addReg(RL78::RP0, RegState::Kill)
            .addReg(Reg, RegState::Kill);
      } else {
        BuildMI(MBB, MI, DL, TII->get(RL78::PUSH_rp))
            .addReg(RL78::RP0, RegState::Kill);
        // Any 16-bit register: SP and MACRL/MACRH have their own moves.
        TII->copyPhysReg(MBB, MI, DL, RL78::RP0, Reg, true);
        // OBS. the order of the next 2 instruction is not wrong, they will be
        // inserted in the right order
        BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(RL78::POP_rp),
                RL78::RP0);
        // Only if the operand is def we need to copy it back from AX.
        if (MI.getOperand(opIndex).isDef())
          TII->copyPhysReg(MBB, std::next(MI.getIterator()), DL, Reg,
                           RL78::RP0, true);

        // In case of stack operations we need to compensate for the stack
        // pointer change caused by PUSH(SP -= 2).

        int opIdx = 0;
        if (MI.getOpcode() == RL78::STORE16_stack_slot_rp)
          opIdx = 1;
        if (MI.getOpcode() == RL78::LOAD16_rp_stack_slot)
          opIdx = 2;

        if (opIdx) {
          auto opImm = MI.getOperand(opIdx).getImm();
          if (opImm < 254) {
            MI.getOperand(opIdx).setImm(opImm + 2);
          } else {
            // An edge case: when the offset of LOAD16_rp_stack_slot/STORE16_stack_slot_rp is 254, simply
            // bumping the offset by 2 would make it overflow, so we need to do the addressing using BC
            auto II = MachineBasicBlock::iterator(MI);
            BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
                .addReg(RL78::RP2, RegState::Kill);
            BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_SP), RL78::RP2)
                .addReg(RL78::SPreg);
            if (MI.getOpcode() == RL78::LOAD16_rp_stack_slot)
              BuildMI(MBB, II, DL, TII->get(RL78::MOVW_AX_mBCw), RL78::RP0)
                  .addReg(RL78::RP2)
                  .addImm(opImm + 4);
            else
              BuildMI(MBB, II, DL, TII->get(RL78::MOVW_mBCw_AX))
                  .addReg(RL78::RP2)
                  .addImm(opImm + 4)
                  .addReg(RL78::RP0);
            BuildMI(MBB, II, DL, TII->get(RL78::POP_rp), RL78::RP2);
            MI.eraseFromParent();
            // As in this case we erase the original instruction, return here
            return false;
          }
        }
      }
    }
  }
  //
  MI.getOperand(opIndex).ChangeToRegister(RL78::RP0,
                                          (opIndex == 0) ? true : false);
  // is it tied to operand1?
  if ((opIndex == 0) && MI.getOperand(opIndex).isTied())
    MI.getOperand(1).ChangeToRegister(RL78::RP0, false);
  return true;
}

static bool isXCH(const MachineInstr &MI) {
  return MI.getOpcode() == RL78::XCH_A_r || MI.getOpcode() == RL78::XCH_A_X;
}

// The spill pseudo, its register now A or AX, as the hardware move it is.
static void toHardwareMove(MachineInstr &MI, const TargetInstrInfo *TII) {
  bool Load = MI.getOperand(0).isReg() && MI.getOperand(0).isDef();
  bool SP = MI.getOperand(Load ? 1 : 0).getReg() == RL78::SPreg;
  unsigned Opc;
  switch (MI.getOpcode()) {
  default:
    llvm_unreachable("not a spill pseudo");
  case RL78::LOAD8_r_stack_slot:
    Opc = SP ? RL78::MOV_A_mSPi : RL78::MOV_A_mRPi;
    break;
  case RL78::LOAD16_rp_stack_slot:
    Opc = SP ? RL78::MOVW_AX_mSPi : RL78::MOVW_AX_mRPi;
    break;
  case RL78::STORE8_stack_slot_r:
    Opc = SP ? RL78::MOV_mSPi_A : RL78::MOV_mRPi_A;
    break;
  case RL78::STORE16_stack_slot_rp:
    Opc = SP ? RL78::MOVW_mSPi_AX : RL78::MOVW_mRPi_AX;
    break;
  }
  MI.setDesc(TII->get(Opc));
}

static void updateAAXLiveness(const MachineInstr &MI, bool &isALive,
                              bool &isXLive) {
  if (MI.isKill()) {
    isALive = isXLive = true;
    return;
  }
  // first mark is(A/AX)Live as false if A/AX isKill
  for (unsigned idx = 0, e = MI.getNumOperands(); idx != e; ++idx) {
    if (MI.getOperand(idx).isReg() && MI.getOperand(idx).isKill()) {
      if (MI.getOperand(idx).getReg() == RL78::R1)
        isALive = false;
      if (MI.getOperand(idx).getReg() == RL78::R0)
        isXLive = false;
      else if (MI.getOperand(idx).getReg() == RL78::RP0)
        isXLive = isALive = false;
    }
  }

  // second mark is(A/AX)Live as true if A/AX isDef
  if (MI.getOpcode() == TargetOpcode::BUNDLE ||
      MI.getOpcode() == RL78::XCHW_AX_rp ||
      MI.getOpcode() == RL78::XCH_A_r || MI.getOpcode() == RL78::XCH_A_X ||
      MI.isCall()) {
    // Bundle instructions can have multiple defs
    // Call defs are not first
    for (unsigned idx = 0, e = MI.getNumOperands(); idx != e; ++idx) {
      if (MI.getOperand(idx).isReg() && MI.getOperand(idx).isDef() &&
          !MI.getOperand(idx).isDead()) {
        if (MI.getOperand(idx).getReg() == RL78::R1)
          isALive = true;
        if (MI.getOperand(idx).getReg() == RL78::R0)
          isXLive = true;
        else if (MI.getOperand(idx).getReg() == RL78::RP0)
          isXLive = isALive = true;
      }
    }
  } else {
    if (MI.getNumOperands() > 0 && MI.getOperand(0).isReg() &&
        MI.getOperand(0).isDef() && !MI.getOperand(0).isDead()) {
      if (MI.getOperand(0).getReg() == RL78::R1)
        isALive = true;
      if (MI.getOperand(0).getReg() == RL78::R0)
        isXLive = true;
      else if (MI.getOperand(0).getReg() == RL78::RP0)
        isALive = isXLive = true;
    }
  }
}

// The instruction before I, skipping debug instructions, or MBB.end() if
// there is none: the peepholes below must see the same code with -g.
static MachineBasicBlock::iterator prevNonDebug(MachineBasicBlock &MBB,
                                                MachineBasicBlock::iterator I) {
  while (I != MBB.begin()) {
    --I;
    if (!I->isDebugInstr())
      return I;
  }
  return MBB.end();
}

// The instruction after I, skipping debug instructions, or MBB.end().
static MachineBasicBlock::iterator nextNonDebug(MachineBasicBlock &MBB,
                                                MachineBasicBlock::iterator I) {
  return skipDebugInstructionsForward(std::next(I), MBB.end());
}

// Replace:
// MOVW AX, RP
// <OP> AX, <...>
// MOVW RP, AX<isKIll>
// With:
// <OP> RP, <...>
void RemoveMOVWs(MachineInstr &MI, MachineBasicBlock &MBB,
                 MachineBasicBlock::iterator &Next, llvm::Register Reg = 0) {

  auto PrevIt = prevNonDebug(MBB, MI.getIterator());
  auto NextIt = nextNonDebug(MBB, MI.getIterator());
  if (MI.getOperand(0).getReg() == RL78::RP0 && PrevIt != MBB.end() &&
      NextIt != MBB.end()) {
    MachineInstr &MI2 = *PrevIt;
    MachineInstr &MI3 = *NextIt;
    if ((MI2.getOpcode() == RL78::MOVW_AX_rp) &&
        (MI3.getOpcode() == RL78::MOVW_rp_AX) &&
        (MI3.getOperand(0).getReg() == MI2.getOperand(1).getReg()) &&
        (!Reg || (MI2.getOperand(1).getReg() == Reg)) &&
        MI3.getOperand(1).isKill()) {
      assert(MI2.getOperand(0).getReg() == RL78::RP0);
      assert(MI3.getOperand(1).getReg() == RL78::RP0);
      MI.getOperand(0).ChangeToRegister(MI2.getOperand(1).getReg(), true);
      MI.getOperand(1).ChangeToRegister(MI2.getOperand(1).getReg(), false);
      // We need to update the iterator before erasing MI3.
      Next = std::next(MachineBasicBlock::iterator(MI3));
      // Remove the MOVW instructions.
      MI2.eraseFromParent();
      MI3.eraseFromParent();
    }
  }
}

bool ReplaceStoreWithPush(MachineInstr &MI, MachineBasicBlock &MBB,
                          DebugLoc &DL, const TargetInstrInfo *TII) {
  auto I = MachineBasicBlock::iterator(MI);
  auto PrevIt = prevNonDebug(MBB, I);
  if (PrevIt == MBB.end())
    return false;
  Register Reg = MI.getOperand(2).getReg();

  // Replace the unnecessary movw instruction and change the register of the 'push'
  // instruction with the register of the movw.
  if (MI.getOpcode() == RL78::STORE16_stack_slot_rp &&
      MI.getOperand(1).getImm() == 0) {
    // The instructions might come one after the other, or there might be a
    // CALL_STACK_SETUP between them.
    if (PrevIt->getOpcode() == RL78::PUSH_rp) {
      PrevIt->getOperand(0).setReg(Reg);
      MI.eraseFromParent();
      return true;
    } else if (PrevIt->getOpcode() == RL78::CALL_STACK_SETUP) {
      auto PushInstr = prevNonDebug(MBB, PrevIt);
      if (PushInstr == MBB.end())
        return false;
      if (PushInstr->getOpcode() == RL78::PUSH_rp) {
        PushInstr->getOperand(0).setReg(Reg);
        MI.eraseFromParent();
        return true;
      }
    }
  }

  if (MI.getOpcode() != RL78::STORE16_stack_slot_rp)
    return false;

  // In the case of:
  // subw sp, #4
  // movw [sp+0], ax
  // movw [sp+2], ax
  // or
  // subw sp, #4
  // movw [sp+2], ax
  // movw [sp+0], ax
  // Eliminate the 2 unnecessary movws, since 2 pushes already save X
  // value to [sp+0] / [sp+2].

  int MIOffset = MI.getOperand(1).getImm();
  if (MIOffset != 0 && MIOffset != 2)
      return false;

  Reg = MI.getOperand(2).getReg();

  I = MI.getIterator();
  PrevIt = prevNonDebug(MBB, I);
  if (PrevIt == MBB.end() || PrevIt->getOpcode() != RL78::STORE16_stack_slot_rp)
      return false;

  // Check if the 2nd movw has an offset of 0 or 2, and uses a different
  // register than the 1st movw.
  int PrevOffset = PrevIt->getOperand(1).getImm();
  if ((PrevOffset != 0 && PrevOffset != 2) || PrevOffset == MIOffset)
      return false;

  if (PrevIt->getOperand(2).getReg() != Reg)
      return false;

  auto SubwIt = prevNonDebug(MBB, PrevIt);
  if (SubwIt == MBB.end())
      return false;
  if (SubwIt->getOpcode() == RL78::SUBW_SP_i8 &&
      SubwIt->getOperand(2).getImm() == 4) {
      BuildMI(MBB, I, DL, TII->get(RL78::PUSH_rp)).addReg(Reg);
      BuildMI(MBB, I, DL, TII->get(RL78::PUSH_rp)).addReg(Reg);

      PrevIt->eraseFromParent();
      MI.eraseFromParent();
      SubwIt->eraseFromParent();
      return true;
  }

  // There might be a stack setup between the subw and the first movw, so the
  // SubwIt is actually a CALL_STACK_SETUP.
  auto StackSetupIt = SubwIt;
  if (StackSetupIt->getOpcode() == RL78::CALL_STACK_SETUP) {
      auto SubwIt = prevNonDebug(MBB, StackSetupIt);
      if (SubwIt == MBB.end())
      return false;

      if (SubwIt->getOpcode() == RL78::SUBW_SP_i8 &&
          SubwIt->getOperand(2).getImm() == 4) {
      BuildMI(MBB, I, DL, TII->get(RL78::PUSH_rp)).addReg(Reg);
      BuildMI(MBB, I, DL, TII->get(RL78::PUSH_rp)).addReg(Reg);

      PrevIt->eraseFromParent();
      MI.eraseFromParent();
      SubwIt->eraseFromParent();
      return true;
      }
  }
  return false;
}


// A stack slot can only be loaded into AX, so loading one into another pair
// while AX is live costs an xchw pair. Move the load back to where AX is dead
// and a single MOVW AX + MOVW rp, AX will do instead.
// "movw [sp+0], rp" right after a push (possibly with a CALL_STACK_SETUP in
// between), which ReplaceStoreWithPush folds into the push.
static bool isStoreFoldableIntoPush(MachineBasicBlock &MBB,
                                    MachineBasicBlock::iterator It) {
  if (It->getOpcode() != RL78::STORE16_stack_slot_rp ||
      It->getOperand(1).getImm() != 0)
    return false;
  auto Prev = prevNonDebug(MBB, It);
  if (Prev != MBB.end() && Prev->getOpcode() == RL78::CALL_STACK_SETUP)
    Prev = prevNonDebug(MBB, Prev);
  return Prev != MBB.end() && Prev->getOpcode() == RL78::PUSH_rp;
}

// The frame index of the slot the spill pseudo \p MI accesses if the
// register allocator made that slot (nothing the program names is in it
// then), or -1.
static int getAllocatorSlot(const MachineInstr &MI,
                            const MachineFrameInfo &MFI) {
  if (!MI.hasOneMemOperand())
    return -1;
  const auto *FS = dyn_cast_or_null<FixedStackPseudoSourceValue>(
      (*MI.memoperands_begin())->getPseudoValue());
  if (!FS || !MFI.isSpillSlotObjectIndex(FS->getFrameIndex()))
    return -1;
  return FS->getFrameIndex();
}

// Whether \p Other, which loads or stores, may access the two bytes at
// [Base+Offset]. An access to another slot through the same base does not.
// When the slot is the allocator's, \p SpillSlot, neither does an access to
// memory the program names or to another frame object.
static bool mayAccessSlot(const MachineInstr &Other, Register Base,
                          int64_t Offset, int SpillSlot) {
  switch (Other.getOpcode()) {
  case RL78::LOAD8_r_stack_slot:
  case RL78::LOAD16_rp_stack_slot:
    return Other.getOperand(1).getReg() != Base ||
           std::abs(Other.getOperand(2).getImm() - Offset) < 2;
  case RL78::STORE8_stack_slot_r:
  case RL78::STORE16_stack_slot_rp:
    return Other.getOperand(0).getReg() != Base ||
           std::abs(Other.getOperand(1).getImm() - Offset) < 2;
  default:
    return SpillSlot < 0 || Other.memoperands_empty() ||
           any_of(Other.memoperands(), [&](const MachineMemOperand *MMO) {
             if (MMO->getValue())
               return false;
             const auto *FS = dyn_cast_or_null<FixedStackPseudoSourceValue>(
                 MMO->getPseudoValue());
             return !FS || FS->getFrameIndex() == SpillSlot;
           });
  }
}

static bool moveLoadToWhereAXIsDead(MachineBasicBlock &MBB,
                                    const TargetRegisterInfo *TRI) {
  const MachineFrameInfo &MFI = MBB.getParent()->getFrameInfo();
  // Bounds both the pass and how far the destination's live range stretches.
  const unsigned WindowSize = 8;
  bool ChangedAny = false;

  for (bool Changed = true; Changed;) {
    Changed = false;

    // Recomputed each round because a move invalidates it.
    DenseMap<const MachineInstr *, bool> AXLiveBefore;
    {
      LivePhysRegs LPR(*TRI);
      LPR.addLiveOuts(MBB);
      for (MachineInstr &MI : llvm::reverse(MBB)) {
        LPR.stepBackward(MI);
        AXLiveBefore[&MI] =
            LPR.contains(RL78::R1) || LPR.contains(RL78::R0);
      }
    }

    for (MachineInstr &MI : MBB) {
      if (MI.getOpcode() != RL78::LOAD16_rp_stack_slot)
        continue;
      Register Dst = MI.getOperand(0).getReg();
      if (Dst == RL78::RP0 || !AXLiveBefore.lookup(&MI))
        continue;
      Register Base = MI.getOperand(1).getReg();
      int64_t Offset = MI.getOperand(2).getImm();
      int SpillSlot = getAllocatorSlot(MI, MFI);

      MachineBasicBlock::iterator Target = MBB.end();
      MachineBasicBlock::iterator It(MI);
      for (unsigned N = 0; N != WindowSize && It != MBB.begin();) {
        --It;
        // Debug instructions neither count nor block: -g must not change code.
        if (It->isDebugInstr())
          continue;
        ++N;
        MachineInstr &Prev = *It;
        // A store may write the slot being loaded, and moving SP changes what
        // [sp+N] means.
        if (Prev.isCall() || Prev.isTerminator() || Prev.isInlineAsm() ||
            Prev.hasUnmodeledSideEffects() ||
            Prev.modifiesRegister(RL78::SPreg, TRI) ||
            Prev.modifiesRegister(Base, TRI))
          break;
        if (Prev.mayStore() && mayAccessSlot(Prev, Base, Offset, SpillSlot))
          break;
        if (Prev.readsRegister(Dst, TRI) || Prev.modifiesRegister(Dst, TRI))
          break;
        if (!AXLiveBefore.lookup(&Prev))
          Target = It; // Keep looking for an earlier free spot.
      }

      if (Target != MBB.end()) {
        MBB.splice(Target, &MBB, MachineBasicBlock::iterator(MI));
        Changed = ChangedAny = true;
        break; // Liveness is stale now; recompute.
      }
    }

    if (Changed)
      continue;

    // Hoisting a copy out of AX to just after the value was produced ends AX's
    // live range early, which lets the stores in between take the one
    // instruction path. This is the prologue shape: parameters arriving in
    // BC/DE are spilled while AX still holds another one.
    for (MachineInstr &MI : MBB) {
      if (MI.getOpcode() != RL78::MOVW_rp_AX)
        continue;
      Register Dst = MI.getOperand(0).getReg();
      if (Dst == RL78::RP0 || !AXLiveBefore.lookup(&MI))
        continue;

      MachineBasicBlock::iterator Target = MBB.end();
      MachineBasicBlock::iterator It(MI);
      bool SawStore = false;
      for (unsigned N = 0; N != WindowSize && It != MBB.begin();) {
        --It;
        // Debug instructions neither count nor block: -g must not change code.
        if (It->isDebugInstr())
          continue;
        ++N;
        MachineInstr &Prev = *It;
        if (Prev.isCall() || Prev.isTerminator() || Prev.isInlineAsm() ||
            Prev.hasUnmodeledSideEffects())
          break;
        // Keep the prologue together: an instruction moved above frame setup
        // would also come before prologue_end in the line table.
        if (Prev.getFlag(MachineInstr::FrameSetup))
          break;
        // Stop at whatever produced the value being copied.
        if (Prev.modifiesRegister(RL78::RP0, TRI))
          break;
        if (Prev.readsRegister(Dst, TRI) || Prev.modifiesRegister(Dst, TRI))
          break;
        // ReplaceStoreWithPush folds this store into the push before it;
        // splitting the pair would keep the store.
        if (isStoreFoldableIntoPush(MBB, It))
          break;
        if (Prev.mayStore())
          SawStore = true;
        Target = It;
      }

      // Only worth it if it frees AX for a store that would otherwise exchange.
      if (Target != MBB.end() && SawStore) {
        // AX is still read by the instructions the copy moves above.
        for (auto I = Target; &*I != &MI; ++I)
          if (I->readsRegister(RL78::RP0, TRI)) {
            MI.clearRegisterKills(RL78::RP0, TRI);
            break;
          }
        MBB.splice(Target, &MBB, MachineBasicBlock::iterator(MI));
        Changed = ChangedAny = true;
        break;
      }
    }

    if (Changed)
      continue;

    // A pair other than AX is stored while AX is live: xchw, movw [sp+n], ax,
    // xchw. If the pair was copied from AX a few instructions back, store AX
    // there; failing that, store where AX is dead and a MOVW AX, rp will do.
    for (MachineInstr &MI : MBB) {
      if (MI.getOpcode() != RL78::STORE16_stack_slot_rp)
        continue;
      Register Src = MI.getOperand(2).getReg();
      if (Src == RL78::RP0 || !AXLiveBefore.lookup(&MI) ||
          isStoreFoldableIntoPush(MBB, MI.getIterator()))
        continue;
      Register Base = MI.getOperand(0).getReg();
      int64_t Offset = MI.getOperand(1).getImm();
      int SpillSlot = getAllocatorSlot(MI, MFI);

      MachineBasicBlock::iterator Target = MBB.end();
      MachineInstr *Copy = nullptr;
      MachineBasicBlock::iterator It(MI);
      for (unsigned N = 0; N != WindowSize && It != MBB.begin();) {
        --It;
        if (It->isDebugInstr())
          continue;
        ++N;
        MachineInstr &Prev = *It;
        if (Prev.isCall() || Prev.isTerminator() || Prev.isInlineAsm() ||
            Prev.hasUnmodeledSideEffects() ||
            Prev.getFlag(MachineInstr::FrameSetup) ||
            Prev.modifiesRegister(RL78::SPreg, TRI) ||
            Prev.modifiesRegister(Base, TRI))
          break;
        if (Prev.getOpcode() == RL78::MOVW_rp_AX &&
            Prev.getOperand(0).getReg() == Src) {
          Copy = &Prev;
          break;
        }
        if (Prev.modifiesRegister(Src, TRI))
          break;
        // The store must not move above an access to its slot.
        if (Prev.mayLoadOrStore() &&
            mayAccessSlot(Prev, Base, Offset, SpillSlot))
          break;
        if (!AXLiveBefore.lookup(&Prev))
          Target = It; // The earliest place is as good as any.
      }

      if (Copy) {
        // AX is read once more, after the copy.
        bool Kill = Copy->getOperand(1).isKill();
        Copy->getOperand(1).setIsKill(false);
        MI.getOperand(2).setReg(RL78::RP0);
        MI.getOperand(2).setIsKill(Kill);
        MBB.splice(std::next(Copy->getIterator()), &MBB,
                   MachineBasicBlock::iterator(MI));
      } else if (Target != MBB.end()) {
        // Src is still read by the instructions the store moves above.
        MI.getOperand(2).setIsKill(false);
        MBB.splice(Target, &MBB, MachineBasicBlock::iterator(MI));
      } else {
        continue;
      }
      Changed = ChangedAny = true;
      break;
    }
  }
  return ChangedAny;
}

// Whether Reg (or a part of it) is live after MI.
static bool isLiveAfter(MachineBasicBlock &MBB, const MachineInstr &MI,
                        Register Reg, const TargetRegisterInfo *TRI) {
  LivePhysRegs LPR(*TRI);
  LPR.addLiveOuts(MBB);
  for (MachineInstr &I : llvm::reverse(MBB)) {
    if (&I == &MI)
      break;
    LPR.stepBackward(I);
  }
  for (MCRegAliasIterator AI(Reg, TRI, true); AI.isValid(); ++AI)
    if (LPR.contains(*AI))
      return true;
  return false;
}

// A value is reloaded into BC, DE or HL right after AX was set, so the load
// would have to go around AX (xchw, movw ax, [sp+n], xchw). Two shapes where
// loading into AX first is shorter:
//
//   movw ax, r1; rp = [sp+n]; addw ax, rp (rp dead)
//   rp = [sp+n]; movw ax, r1; addw ax, rp (rp dead)
//     -> movw ax, [sp+n]; addw ax, r1
//
//   movw ax, rp; rp = [sp+n]
//     -> movw ax, [sp+n]; xchw ax, rp
static bool loadIntoAXFirst(MachineBasicBlock &MBB,
                            const TargetRegisterInfo *TRI,
                            const TargetInstrInfo *TII) {
  bool Changed = false;
  for (MachineBasicBlock::iterator It = MBB.begin(); It != MBB.end();) {
    MachineInstr &Copy = *It++;
    if (Copy.getOpcode() != RL78::MOVW_AX_rp)
      continue;
    Register Src = Copy.getOperand(1).getReg();
    // The load before the copy: AX is free there, the copy writes it.
    auto PrevIt = prevNonDebug(MBB, Copy.getIterator());
    auto AddIt = nextNonDebug(MBB, Copy.getIterator());
    if (Src != RL78::RP0 && PrevIt != MBB.end() && AddIt != MBB.end() &&
        PrevIt->getOpcode() == RL78::LOAD16_rp_stack_slot &&
        AddIt->getOpcode() == RL78::ADDW_AX_rp) {
      Register Dst = PrevIt->getOperand(0).getReg();
      if (Dst != RL78::RP0 && Dst != Src &&
          RL78::RL78BCDEHLRegClass.contains(Dst) &&
          AddIt->getOperand(2).getReg() == Dst &&
          !isLiveAfter(MBB, *AddIt, Dst, TRI)) {
        PrevIt->getOperand(0).setReg(RL78::RP0);
        AddIt->getOperand(2).setReg(Src);
        AddIt->getOperand(2).setIsKill(false);
        Copy.eraseFromParent();
        Changed = true;
        continue;
      }
    }
    auto LoadIt = nextNonDebug(MBB, Copy.getIterator());
    if (Src == RL78::RP0 || LoadIt == MBB.end() ||
        LoadIt->getOpcode() != RL78::LOAD16_rp_stack_slot)
      continue;
    MachineInstr &Load = *LoadIt;
    Register Dst = Load.getOperand(0).getReg();
    if (Dst == RL78::RP0 || !RL78::RL78BCDEHLRegClass.contains(Dst))
      continue;

    auto UseIt = nextNonDebug(MBB, LoadIt);
    if (UseIt != MBB.end() && UseIt->getOpcode() == RL78::ADDW_AX_rp &&
        UseIt->getOperand(2).getReg() == Dst &&
        !isLiveAfter(MBB, *UseIt, Dst, TRI)) {
      Load.getOperand(0).setReg(RL78::RP0);
      UseIt->getOperand(2).setReg(Src);
      UseIt->getOperand(2).setIsKill(false);
      // Src is now read after the instructions in between.
      for (auto I = std::next(Copy.getIterator()); I != UseIt; ++I)
        I->clearRegisterKills(Src, TRI);
      It = std::next(LoadIt);
      Copy.eraseFromParent();
      Changed = true;
      continue;
    }

    if (Dst != Src)
      continue;
    Load.getOperand(0).setReg(RL78::RP0);
    BuildMI(MBB, std::next(LoadIt), Load.getDebugLoc(),
            TII->get(RL78::XCHW_AX_rp), RL78::RP0)
        .addReg(Dst, RegState::Define)
        .addReg(RL78::RP0, RegState::Kill)
        .addReg(Dst, RegState::Kill);
    It = std::next(LoadIt);
    Copy.eraseFromParent();
    Changed = true;
  }
  return Changed;
}

bool RL78InsertExchangeInstructionsPass::runOnMachineFunction(
    MachineFunction &MF) {
  const TargetInstrInfo *TII = MF.getSubtarget<RL78Subtarget>().getInstrInfo();
  LLVM_DEBUG(dbgs() << "********** INSERT EXCHANGE INSTRUCTIONS **********\n"
                    << "********** Function: " << MF.getName() << '\n');
  // LiveIntervals *LIS = &getAnalysis<LiveIntervals>();
  // LIS->dump();
  // LiveDebugVariables *DebugVars = &getAnalysis<LiveDebugVariables>();
  LLVM_DEBUG(MF.dump());
  // first step remove pseudos and insert real intructions and XCH instructions
  // where necesarry
  const TargetRegisterInfo *TRI = MF.getSubtarget().getRegisterInfo();

  // Before the liveness below: this changes which exchanges are needed.
  if (RL78AccumSched)
    for (MachineBasicBlock &MBB : MF)
      if (!MBB.empty()) {
        moveLoadToWhereAXIsDead(MBB, TRI);
        loadIntoAXFirst(MBB, TRI, TII);
      }

  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;

    // updateAAXLiveness() below is a forward def-tracking walk and cannot
    // prove deadness, so use real liveness instead.
    DenseMap<const MachineInstr *, std::pair<bool, bool>> LiveBeforeMI;
    // Physreg kill flags are unreliable this late, so "A dead afterwards" is
    // answered from here rather than from isKill().
    DenseMap<const MachineInstr *, bool> ALiveAfterMI;
    bool CCLiveOut;
    {
      LivePhysRegs LPR(*TRI);
      LPR.addLiveOuts(MBB);
      CCLiveOut = LPR.contains(RL78::CCreg);
      for (MachineInstr &MI : llvm::reverse(MBB)) {
        ALiveAfterMI[&MI] = LPR.contains(RL78::R1);
        LPR.stepBackward(MI);
        LiveBeforeMI[&MI] = {LPR.contains(RL78::R1), LPR.contains(RL78::R0)};
      }
    }

    bool isALive = MBB.isLiveIn(RL78::R1) || MBB.isLiveIn(RL78::RP0);
    bool isXLive = MBB.isLiveIn(RL78::R0) || MBB.isLiveIn(RL78::RP0);

    for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end();
         Next != E;) {
      MachineInstr &MI = *Next;
      DebugLoc DL = MI.getDebugLoc();
      ++Next;
      updateAAXLiveness(MI, isALive, isXLive);
      // Instructions inserted below are absent and keep the conservative answer.
      auto LB = LiveBeforeMI.find(&MI);
      if (LB != LiveBeforeMI.end()) {
        isALive = LB->second.first;
        isXLive = LB->second.second;
      }
      // MI.dump();
      switch (MI.getOpcode()) {
      case RL78::MOV_r_i8:
        assert(MI.getOperand(1).isImm());
        // Replace mov X, A + mov A, #0 with shrw AX, 8.
        if ((MI.getOperand(0).getReg() == RL78::R1) &&
            (MI.getOperand(1).getImm() == 0) &&
            prevNonDebug(MBB, MI.getIterator()) != MBB.end()) {
          MachineInstr &MI2 = *prevNonDebug(MBB, MI.getIterator());
          if ((MI2.getOpcode() == RL78::MOV_r_A) &&
              (MI2.getOperand(0).getReg() == RL78::R0)) {
            assert(MI2.getOperand(1).getReg() == RL78::R1);
            // Build the SHRW instruction.
            BuildMI(MBB, MI, DL, TII->get(RL78::SHRW_AX_n), RL78::RP0)
                .addReg(RL78::RP0, RegState::Kill)
                .addImm(8);
            // Remove MOV instructions.
            MI.eraseFromParent();
            MI2.eraseFromParent();
            break;
          }
        }
        // If dest is A/X/B/C we might be able to use CLRB/ONEB.
        if (RL78::RL78LowRegClass.contains(MI.getOperand(0).getReg())) {
          if (MI.getOperand(1).isImm()) {
            if (MI.getOperand(1).getImm() == 0) {
              // Build the CLRB instruction.
              BuildMI(MBB, MI, DL, TII->get(RL78::CLRB_r))
                  .add(MI.getOperand(0));
              // Erase the MOV instruction.
              MI.eraseFromParent();
            } else if (MI.getOperand(1).getImm() == 1) {
              // Build the CLRB instruction.
              BuildMI(MBB, MI, DL, TII->get(RL78::ONEB_r))
                  .add(MI.getOperand(0));
              // Erase the MOV instruction.
              MI.eraseFromParent();
            }
          }
        }
        break;
      case RL78::MOVW_rp_i16:
        // If dest is AX/BC we might be able to use CLRW/ONEW.
        if (RL78::RL78AXBCRPRegClass.contains(MI.getOperand(0).getReg())) {
          if (MI.getOperand(1).isImm()) {
            if (MI.getOperand(1).getImm() == 0) {
              // Build the CLRW instruction.
              BuildMI(MBB, MI, DL, TII->get(RL78::CLRW_rp))
                  .add(MI.getOperand(0));
              // Erase the MOVW instruction.
              MI.eraseFromParent();
            } else if (MI.getOperand(1).getImm() == 1) {
              // Build the ONEW instruction.
              BuildMI(MBB, MI, DL, TII->get(RL78::ONEW_rp))
                  .add(MI.getOperand(0));
              // Erase the MOVW instruction.
              MI.eraseFromParent();
            }
            // The following optimizations reduce only code size and
            // they increase cycles count so we don't do them when optimizing
            // for speed.
            else if (MF.getFunction().hasOptSize()) {
              // 3 to 2 bytes, 1 cycle to 2
              // 1. MOVW AX, #0x100 can be replaced with ONEB A + CRLB X.
              // 2. MOVW AX, #0x101 can be replaced with ONEB A + ONEB X.
              if ((MI.getOperand(1).getImm() == 0x100) ||
                  (MI.getOperand(1).getImm() == 0x101)) {
                unsigned RHi = RL78::R1;
                unsigned RLo = RL78::R0;
                unsigned opcode = (MI.getOperand(1).getImm() == 0x101)
                                      ? RL78::ONEB_r
                                      : RL78::CLRB_r;
                if (MI.getOperand(0).getReg() == RL78::RP2) {
                  RHi = RL78::R3;
                  RLo = RL78::R2;
                }
                // Build the ONEB/CLRB instructions.
                BuildMI(MBB, MI, DL, TII->get(RL78::ONEB_r), RHi);
                BuildMI(MBB, MI, DL, TII->get(opcode), RLo);
                // Erase the MOVW instruction.
                MI.eraseFromParent();
              }
              // 3. MOVW AX, #-1 (3 bytes, 2/1 clocks) can be replaced with CLRW
              // AX (1 byte, 1 clock) + DECW AX(1 byte, 2/1 clocks)
              if (MI.getOperand(1).getImm() == -1) {
                BuildMI(MBB, MI, DL, TII->get(RL78::CLRW_rp))
                    .add(MI.getOperand(0));
                BuildMI(MBB, MI, DL, TII->get(RL78::DECW_rp))
                    .add(MI.getOperand(0))
                    .addReg(MI.getOperand(0).getReg(), RegState::Kill);
                MI.eraseFromParent();
              }
            }
          }
        }
        break;
      case RL78::SHL_r_n:
        // Replace MOV R1, (R2/R3) + SHL R2/R3, #imm + MOV (R2/R3), R1 with SHL R2/R3, #imm.
        if (MI.getOperand(0).getReg() == RL78::R1 &&
            prevNonDebug(MBB, MI.getIterator()) != MBB.end() &&
            nextNonDebug(MBB, MI.getIterator()) != MBB.end()) {
          MachineInstr &MI2 = *prevNonDebug(MBB, MI.getIterator());
          MachineInstr &MI3 = *nextNonDebug(MBB, MI.getIterator());
          if ((MI2.getOpcode() == RL78::MOV_A_r) &&
              ((MI2.getOperand(1).getReg() == RL78::R2) ||
               (MI2.getOperand(1).getReg() == RL78::R3)) &&
              (MI3.getOpcode() == RL78::MOV_r_A) &&
              ((MI3.getOperand(0).getReg() == RL78::R2) ||
               (MI3.getOperand(0).getReg() == RL78::R3)) &&
              (MI2.getOperand(1).getReg() == MI3.getOperand(0).getReg()) &&
              MI3.getOperand(1).isKill()) {
            assert(MI2.getOperand(0).getReg() == RL78::R1);
            assert(MI3.getOperand(1).getReg() == RL78::R1);
            MI.getOperand(0).ChangeToRegister(MI2.getOperand(1).getReg(), true);
            MI.getOperand(1).ChangeToRegister(MI2.getOperand(1).getReg(),
                                              false);
            // We need to update the iterator before erasing MI3.
            Next = std::next(MachineBasicBlock::iterator(MI3));
            // Remove the MOV instructions.
            MI2.eraseFromParent();
            MI3.eraseFromParent();
          }
        }
        break;
      case RL78::SHLW_rp_n:
        RemoveMOVWs(MI, MBB, Next, RL78::RP2);
        break;
      case RL78::SUBW_AX_rp: {
        // SUBW ax, ax is not permitted.
        if (MI.getOperand(2).getReg() == RL78::RP0 &&
            MI.getOperand(1).getReg() == MI.getOperand(2).getReg()) {
          BuildMI(MBB, MI, DL, TII->get(RL78::CLRW_rp))
              .addReg(MI.getOperand(0).getReg());
          MI.eraseFromParent();
        }
        break;
      }
      case RL78::CLRB_r:
        // Replace MOV X, A + CLRB A with SHRW AX.
        if (prevNonDebug(MBB, MI.getIterator()) != MBB.end()) {
          MachineInstr &MI2 = *prevNonDebug(MBB, MI.getIterator());
          if ((MI.getOperand(0).getReg() == RL78::R1) &&
              (MI2.getOpcode() == RL78::MOV_r_A) &&
              (MI2.getOperand(0).getReg() == RL78::R0)) {
            assert(MI2.getOperand(1).getReg() == RL78::R1);
            // Build the SHRW instruction.
            BuildMI(MBB, MI, DL, TII->get(RL78::SHRW_AX_n), RL78::RP0)
                .addReg(RL78::RP0, RegState::Kill).addImm(8);
            // Remove the MOV and CLRB instructions.
            MI.eraseFromParent();
            MI2.eraseFromParent();
          }
        }
        break;
      case RL78::CMP_A_mHLi:
        // Replace MOV A, X + CMP A, [HL+byte] with CMPS X, [HL+byte].
        //
        // ExpandPostRAPseudos has already turned the copy feeding A into a real
        // MOV_A_r, so matching RL78::COPY here would never fire.
        {
          auto AAfter = ALiveAfterMI.find(&MI);
          bool ADeadAfter =
              (AAfter != ALiveAfterMI.end()) ? !AAfter->second : false;
          // The MOV may be separated from the CMP by instructions that do not
          // touch A or X (setting up HL, say).
          MachineBasicBlock::iterator MovIt = prevNonDebug(MBB, MI.getIterator());
          while (MovIt != MBB.end() && MovIt->getOpcode() != RL78::MOV_A_r &&
                 !MovIt->isCall() && !MovIt->hasUnmodeledSideEffects() &&
                 !MovIt->readsRegister(RL78::R1, TRI) &&
                 !MovIt->modifiesRegister(RL78::R1, TRI) &&
                 !MovIt->modifiesRegister(RL78::R0, TRI))
            MovIt = prevNonDebug(MBB, MovIt);
          if (ADeadAfter && MovIt != MBB.end() &&
              !MI.registerDefIsDead(RL78::CCreg, TRI) && !CCLiveOut) {
            MachineInstr &MI2 = *MovIt;
            if ((MI2.getOpcode() == RL78::MOV_A_r) &&
                (MI2.getOperand(1).getReg() == RL78::R0) &&
                (MI2.getOperand(0).getReg() == RL78::R1)) {
              MachineBasicBlock::iterator I = MBB.getLastNonDebugInstr();
              // CCreg is live and block-local, so its consumer is this branch.
              // CMPS is only usable when that tests Z; CY means something else.
              if ((I != MBB.end()) && I->isBranch() &&
                  (I->getNumOperands() > 1) && I->getOperand(1).isImm() &&
                  ((I->getOperand(1).getImm() == RL78CC::RL78CC_Z) ||
                   (I->getOperand(1).getImm() == RL78CC::RL78CC_NZ))) {
                // Build the CMPS instruction.
                BuildMI(MBB, MI, DL, TII->get(RL78::CMPS_X_mHLi))
                    .add(MI2.getOperand(1))
                    .add(MI.getOperand(1))
                    .add(MI.getOperand(2));
                // Erase the MOV and CMP instructions.
                MI.eraseFromParent();
                MI2.eraseFromParent();
                // MBB.dump();
              }
            }
          }
        }
        break;
      case RL78::ADDW_AX_i16:
        // INCW/DECW instructions don't update the CCreg.
        if (!MI.registerDefIsDead(RL78::CCreg, TRI) ||
            !MI.getOperand(2).isImm())
          break;
        // If imm == 1 INCW (and DECW in case of -1) will be selected
        // If imm == 2 we case use 2 x INCW (for code size only):
        // size of "INCW rp" is 1 bytes while size of "ADDW ax, #imm" is 3
        // bytes.
        if (MI.getOperand(2).getImm() == 2) {
          RemoveMOVWs(MI, MBB, Next);
          // Insert 2 x INCW instructions
          BuildMI(MBB, MI, DL, TII->get(RL78::INCW_rp))
              .add(MI.getOperand(0))
              .addReg(MI.getOperand(1).getReg());
          BuildMI(MBB, MI, DL, TII->get(RL78::INCW_rp))
              .add(MI.getOperand(0))
              .add(MI.getOperand(1));
          // Erase the ADDW instruction.
          MI.eraseFromParent();
        }
        // If imm == -2 we case use 2 x DECW.
        else if (MI.getOperand(2).getImm() == -2) {
          RemoveMOVWs(MI, MBB, Next);
          // Insert 2 x DECW instructions
          BuildMI(MBB, MI, DL, TII->get(RL78::DECW_rp))
              .add(MI.getOperand(0))
              .addReg(MI.getOperand(1).getReg());
          BuildMI(MBB, MI, DL, TII->get(RL78::DECW_rp))
              .add(MI.getOperand(0))
              .add(MI.getOperand(1));
          // Erase the ADDW instruction.
          MI.eraseFromParent();
        }
        break;
      case RL78::LOAD16_rp_stack_slot:
        if (insert16BitExchange(MI, 0, DL, MBB, TII, isALive || isXLive))
          toHardwareMove(MI, TII);
        break;
      case RL78::LOAD8_r_stack_slot:
        insert8BitExchange(MI, 0, DL, MBB, TII, isALive);
        toHardwareMove(MI, TII);
        break;
      case RL78::STORE16_stack_slot_rp:
        if (!ReplaceStoreWithPush(MI, MBB, DL, TII) &&
            insert16BitExchange(MI, 2, DL, MBB, TII, isALive || isXLive))
          toHardwareMove(MI, TII);
        break;
      case RL78::STORE8_stack_slot_r:
        insert8BitExchange(MI, 2, DL, MBB, TII, isALive);
        toHardwareMove(MI, TII);
        break;
      case RL78::HI16_rp_rp: {
        Register dst = MI.getOperand(0).getReg();
        Register src = MI.getOperand(1).getReg();
        if (dst != src) {
          if (dst == RL78::RP0) {
            BuildMI(MBB, MI, DL, TII->get(RL78::MOVW_AX_rp), dst)
                .add(MI.getOperand(1));
          } else if (src == RL78::RP0) {
            BuildMI(MBB, MI, DL, TII->get(RL78::MOVW_rp_AX), dst)
                .add(MI.getOperand(1));
          } else {
            BuildMI(MBB, MI, DL, TII->get(RL78::PUSH_rp))
                .add(MI.getOperand(1));
            BuildMI(MBB, MI, DL, TII->get(RL78::POP_rp), dst);
          }
        }
        MI.removeFromParent();
      } break;
      case RL78::CMPW_AX_i16:
        if (MI.getOperand(1).isImm() && MI.getOperand(1).getImm() == 0) {
          auto It1 = skipDebugInstructionsForward(Next, MBB.end());
          if (It1 == MBB.end())
            break;
          MachineInstr &MI1 = *It1;
          auto It2 = skipDebugInstructionsForward(std::next(It1), MBB.end());
          if (It2 == MBB.end())
            break;
          MachineInstr &MI2 = *It2;
          // ADDW AX, AX overwrites all of AX, so neither half may be needed
          // after the XOR1 (which reads only A).
          auto LB2 = LiveBeforeMI.find(&MI2);
          bool AXDeadAfter = LB2 != LiveBeforeMI.end() && !LB2->second.first &&
                             !LB2->second.second;
          if ((MI1.getOpcode() == RL78::XOR1_CY_A_b) && AXDeadAfter &&
              (MI2.getOpcode() == RL78::BRCC) &&
              ((MI2.getOperand(1).getImm() == RL78CC::RL78CC_H) ||
                (MI2.getOperand(1).getImm() == RL78CC::RL78CC_NH))) {
            Next = std::next(It2);
            BuildMI(MBB, MI, DL, TII->get(RL78::ADDW_AX_rp))
                .addReg(RL78::RP0, RegState::DefineNoRead)
                .addReg(RL78::RP0, RegState::Kill)
                .addReg(RL78::RP0, RegState::Kill);
              MI.eraseFromParent();
              MI1.eraseFromParent();
          }
        }
        break;
      }
    }
  }

  // second step unecesarry instruction sequences:
  // case 1:
  // XCH(W) A, rx
  // XCH(W) A, rx
  // case 2:
  // XCH A, rx
  // COPY A, rx<kill>
  // case 3:
  // POP rx
  // PUSH rx
  LLVM_DEBUG(MF.dump());
  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;
    for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end();
         Next != E;) {
      MachineInstr &MI1 = *Next;
      ++Next;
      if (MI1.isDebugInstr())
        continue;
      // Pairs are matched across debug instructions, as without -g.
      Next = skipDebugInstructionsForward(Next, MBB.end());
      // if this wasn't the last instruction in BB
      if (Next != MBB.end()) {
        MachineInstr &MI2 = *Next;
        
        // if the 2 opcodes are equal, XCH/XCHW instructions using the same
        // registers(first one is A anyways)
        if ((MI1.getOpcode() == MI2.getOpcode()) &&
            (isXCH(MI1) || MI1.getOpcode() == RL78::XCHW_AX_rp) &&
            (MI1.getOperand(1).getReg() == MI2.getOperand(1).getReg())) {
          // update iterator
          ++Next;
          // remove them both
          MI1.eraseFromParent();
          MI2.eraseFromParent();
        } else if ((MI2.getOpcode() == RL78::COPY) &&
                   (MI2.getOperand(1).isKill()) &&
                   (((isXCH(MI1)) &&
                     (MI2.getOperand(0).getReg() == RL78::R1)) ||
                    ((MI1.getOpcode() == RL78::XCHW_AX_rp) &&
                     (MI2.getOperand(0).getReg() == RL78::RP0))) &&
                   (MI1.getOperand(1).getReg() == MI2.getOperand(1).getReg())) {
          // update iterator
          ++Next;
          // remove them both
          MI1.eraseFromParent();
          MI2.eraseFromParent();

        } else if ((MI1.getOpcode() == RL78::POP_rp) &&
                   (MI2.getOpcode() == RL78::PUSH_rp) &&
                   (MI1.getOperand(0).getReg() == MI2.getOperand(0).getReg()) &&
                   (MI1.getOperand(0).isKill() && MI2.getOperand(0).isKill())) {
          // update iterator
          ++Next;
          // remove them both
          MI1.eraseFromParent();
          MI2.eraseFromParent();
          // Normally we have the following sequence:
          // MOVW BC, SP
          // <load/store with [BC]>
          // POP BC
          // PUSH BC
          // MOVW BC, SP
          Next = skipDebugInstructionsForward(Next, MBB.end());
          if ((Next != MBB.end())) {
            MachineInstr &MI3 = *Next;
            if ((MI3.getOpcode() == RL78::MOVW_rp_SP) &&
                MI3.getOperand(0).isReg() &&
                (MI3.getOperand(0).getReg() == RL78::RP2)) {
              ++Next;
              MI3.eraseFromParent();
            }
          }
        }
      }
    }
  }
  // 2nd run.
  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;

    for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end();
         Next != E;) {
      MachineInstr &MI1 = *Next;
      ++Next;
      if (MI1.isDebugInstr())
        continue;
      // Pairs are matched across debug instructions, as without -g.
      Next = skipDebugInstructionsForward(Next, MBB.end());
      // if this wasn't the last instruction in BB
      if (Next != MBB.end()) {
        MachineInstr &MI2 = *Next;
        if ((MI1.getOpcode() == RL78::MOVW_rp_AX) &&
            (MI2.getOpcode() == RL78::MOVW_AX_rp) &&
            (MI1.getOperand(0).getReg() == MI2.getOperand(1).getReg()) &&
            MI2.getOperand(1).isKill()) {
          // update iterator
          ++Next;
          // remove them both
          MI1.eraseFromParent();
          MI2.eraseFromParent();
        }
      }
    }
  }
  for (MachineBasicBlock &MBB : MF)
    static_cast<const RL78InstrInfo *>(TII)->setExchangeFlags(MBB);
  LLVM_DEBUG(MF.dump());
  return true;
}
