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

using namespace llvm;

#define DEBUG_TYPE "insert-exchange"

// Plain counters rather than STATISTIC: this build has LLVM_ENABLE_STATS off.
static cl::opt<bool>
    RL78XchgStats("rl78-xchg-stats", cl::Hidden, cl::init(false),
                  cl::desc("Print why each RL78 exchange took the "
                           "two-instruction path"));
static unsigned NumXchg16AXLiveTied, NumXchg16AXLive, NumXchg16TiedOnly,
    NumXchg8AXLive, NumXchg8DefOnly;

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

  bool doFinalization(Module &M) override {
    if (RL78XchgStats) {
      unsigned Tot = NumXchg16AXLiveTied + NumXchg16AXLive + NumXchg16TiedOnly +
                     NumXchg8AXLive + NumXchg8DefOnly;
      errs() << "rl78-xchg-stats: 16bit AXlive+tied " << NumXchg16AXLiveTied
             << ", 16bit AXlive " << NumXchg16AXLive << ", 16bit tied-only "
             << NumXchg16TiedOnly << ", 8bit Alive " << NumXchg8AXLive
             << ", 8bit def-only " << NumXchg8DefOnly << ", total " << Tot
             << "\n";
    }
    return false;
  }

  // private:
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

// if operand(opIndex) is NOT A register (and it needs to be) we need to
// exchange the value to A and back in other words generate the following
// sequence: xch A, Rx op A, <...> xch A, Rx
static void insert8BitExchange(MachineInstr &MI, unsigned opIndex, DebugLoc &DL,
                               MachineBasicBlock &MBB,
                               const TargetInstrInfo *TII, bool isALive,
                               bool isDefOp0 = true) {
  // MBB.dump();
  // MI.dump();

  if (opIndex == 0 && MI.getOpcode() != RL78::XCH_A_r &&
      MI.getOperand(opIndex).isTied()) {
    if ((!isALive) && MI.getOperand(opIndex + 1).isKill()) {
      BuildMI(MBB, MI, DL, TII->get(RL78::MOV_A_r), RL78::R1)
          .addReg(MI.getOperand(opIndex).getReg(), RegState::Kill);
    }
  }

  // if dest is NOT A register we need to exchange the value to A and back
  if (!RL78::RL78ARegRegClass.contains(MI.getOperand(opIndex).getReg())) {
    // Pure use and A dead: MOV leaves the source intact, so no kill needed.
    if ((!isALive) && !MI.getOperand(opIndex).isDef()) {
      BuildMI(MBB, MI, DL, TII->get(RL78::MOV_A_r), RL78::R1)
          .addReg(MI.getOperand(opIndex).getReg(),
                  getKillRegState(MI.getOperand(opIndex).isKill()));
    }
    // if register is "Def"
    else if ((!isALive) && MI.getOperand(opIndex).isDef()) {
      BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(RL78::MOV_r_A),
              MI.getOperand(opIndex).getReg())
          .addReg(RL78::R1, RegState::Kill);
    } else {
      if (isALive)
        ++NumXchg8AXLive;
      else
        ++NumXchg8DefOnly;
      // generate the following sequence:
      // xch A, Rx
      // op A, <...>
      // xch A, Rx
      BuildMI(MBB, MI, DL, TII->get(RL78::XCH_A_r), RL78::R1)
          .addReg(MI.getOperand(opIndex).getReg(), RegState::Define)
          .addReg(RL78::R1, RegState::Kill)
          .addReg(MI.getOperand(opIndex).getReg(), RegState::Kill);
      BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(RL78::XCH_A_r),
              RL78::R1)
          .addReg(MI.getOperand(opIndex).getReg(), RegState::Define)
          .addReg(RL78::R1, RegState::Kill)
          .addReg(MI.getOperand(opIndex).getReg(), RegState::Kill);
    }
  }
  //
  if (MI.getOpcode() != RL78::XCH_A_r) {
    MI.getOperand(opIndex).ChangeToRegister(RL78::R1, isDefOp0);
    // In case we have all 3 operands are equal.
    if (MI.getOpcode() == RL78::XOR_r_r || MI.getOpcode() == RL78::AND_r_r ||
        MI.getOpcode() == RL78::OR_r_r) {
      assert(MI.getOperand(opIndex).isTied());
      if (MI.getOperand(2).getReg() == MI.getOperand(1).getReg())
        MI.getOperand(2).ChangeToRegister(RL78::R1, false);
    }
    // is it tied to operand1?
    if ((opIndex == 0) && MI.getOperand(opIndex).isTied())
      MI.getOperand(1).ChangeToRegister(RL78::R1, false);
  } else {
    if (MI.getOperand(1).getReg() == RL78::R1) {
      MI.getOperand(1).ChangeToRegister(MI.getOperand(0).getReg(), true);
      MI.getOperand(3).ChangeToRegister(MI.getOperand(0).getReg(), true);
    }
    MI.getOperand(0).ChangeToRegister(RL78::R1, true);
    MI.getOperand(2).ChangeToRegister(RL78::R1, false);
  }
  // MBB.dump();
}

// if operand(opIndex) is NOT A register (and it needs to be) we need to
// exchange the value to A and back in other words generate the following
// sequence: xchw AX, RPx op AX, <...> xchw AX, RPx
static void insert16BitExchange(MachineInstr &MI, unsigned opIndex,
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
      BuildMI(MBB, MI, DL, TII->get(RL78::MOVW_AX_rp), RL78::RP0)
          .addReg(Reg, getKillRegState(MI.getOperand(opIndex).isKill()));
    }
    // Pure def and AX dead: copy out only. A tied operand is also read, so it
    // falls through to the exchange below.
    else if ((!isAXLive) && IsDef && !IsTied) {
      BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(RL78::MOVW_rp_AX),
              Reg)
          .addReg(RL78::RP0, RegState::Kill);
    } else {
      // Ordered so each exchange is attributed to exactly one cause.
      if (isAXLive && IsTied)
        ++NumXchg16AXLiveTied;
      else if (isAXLive)
        ++NumXchg16AXLive;
      else
        ++NumXchg16TiedOnly;
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
        BuildMI(MBB, MI, DL, TII->get(RL78::MOVW_AX_rp), RL78::RP0)
            .addReg(Reg, RegState::Kill);
        // OBS. the order of the next 2 instruction is not wrong, they will be
        // inserted in the right order
        BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(RL78::POP_rp),
                RL78::RP0);
        // Only if the operand is def we need to copy it back from AX.
        if (MI.getOperand(opIndex).isDef())
          BuildMI(MBB, std::next(MI.getIterator()), DL,
                  TII->get(RL78::MOVW_rp_AX), Reg)
              .addReg(RL78::RP0, RegState::Kill);

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
            BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_sp), RL78::RP2)
                .addReg(RL78::SPreg);
            if (MI.getOpcode() == RL78::LOAD16_rp_stack_slot)
              BuildMI(MBB, II, DL, TII->get(RL78::LOAD16_rp_rpi), RL78::RP0)
                  .addReg(RL78::RP2)
                  .addImm(opImm + 4);
            else
              BuildMI(MBB, II, DL, TII->get(RL78::STORE16_rpi_rp))
                  .addReg(RL78::RP2)
                  .addImm(opImm + 4)
                  .addReg(RL78::RP0);
            BuildMI(MBB, II, DL, TII->get(RL78::POP_rp), RL78::RP2);
            MI.eraseFromParent();
            // As in this case we erase the original instruction, return here
            return;
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
  // MBB.dump();
}

static void insertHLExchange(MachineInstr &MI, unsigned opIndex, DebugLoc &DL,
                             MachineBasicBlock &MBB,
                             const TargetInstrInfo *TII) {
  assert(MI.getOperand(opIndex).isReg());
  if (MI.getOperand(opIndex).getReg() != RL78::RP6) {
    unsigned badReg = MI.getOperand(opIndex).getReg();
    BuildMI(MBB, MI, DL, TII->get(RL78::PUSH_rp))
        .addReg(RL78::RP6, RegState::Kill);
    BuildMI(MBB, MI, DL, TII->get(RL78::PUSH_rp))
        .addReg(badReg, RegState::Kill);
    BuildMI(MBB, MI, DL, TII->get(RL78::POP_rp), RL78::RP6);
    MI.getOperand(opIndex).ChangeToRegister(RL78::RP6, false);
    // despite the order here, in the generated code it will be push hl, pop de,
    // pop hl
    BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(RL78::POP_rp))
        .addReg(RL78::RP6, RegState::Define);
    BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(RL78::POP_rp),
            badReg);
    BuildMI(MBB, std::next(MI.getIterator()), DL, TII->get(RL78::PUSH_rp))
        .addReg(RL78::RP6, RegState::Kill);
  }
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
      MI.getOpcode() == RL78::XCH_A_r ||
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

// Replace:
// MOVW AX, RP
// <OP> AX, <...>
// MOVW RP, AX<isKIll>
// With:
// <OP> RP, <...>
void RemoveMOVWs(MachineInstr &MI, MachineBasicBlock &MBB,
                 MachineBasicBlock::iterator &Next, llvm::Register Reg = 0) {

  if (MI.getOperand(0).getReg() == RL78::RP0 &&
      (MachineBasicBlock::iterator(MI) != MBB.begin()) &&
      (MachineBasicBlock::iterator(MI) != MBB.end()) &&
      !MachineBasicBlock::iterator(MI)->isKnownSentinel() &&
      MachineBasicBlock::iterator(MI)->getPrevNode() &&
      !MachineBasicBlock::iterator(MI)->getPrevNode()->isKnownSentinel() &&
      MachineBasicBlock::iterator(MI)->getNextNode() &&
      !MachineBasicBlock::iterator(MI)->getNextNode()->isKnownSentinel()) {
    MachineInstr &MI2 = *std::prev(MachineBasicBlock::iterator(MI));
    MachineInstr &MI3 = *std::next(MachineBasicBlock::iterator(MI));
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
  if (I == MBB.begin())
    return false;

  auto PrevIt = std::prev(I);
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
      auto PushInstr = MachineBasicBlock::iterator(PrevIt);
      if (PushInstr == MBB.begin())
        return false;

      PushInstr = std::prev(PrevIt);
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
  if (I == MBB.begin())
      return false;

  PrevIt = std::prev(I);
  if (PrevIt->getOpcode() != RL78::STORE16_stack_slot_rp)
      return false;

  // Check if the 2nd movw has an offset of 0 or 2, and uses a different
  // register than the 1st movw.
  int PrevOffset = PrevIt->getOperand(1).getImm();
  if ((PrevOffset != 0 && PrevOffset != 2) || PrevOffset == MIOffset)
      return false;

  if (PrevIt->getOperand(2).getReg() != Reg)
      return false;

  if (PrevIt == MBB.begin())
      return false;

  auto SubwIt = std::prev(PrevIt);
  if (SubwIt->getOpcode() == RL78::SUBW_sp_imm &&
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
      if (StackSetupIt == MBB.begin())
      return false;

      auto SubwIt = std::prev(StackSetupIt);

      if (SubwIt->getOpcode() == RL78::SUBW_sp_imm &&
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
static bool moveLoadToWhereAXIsDead(MachineBasicBlock &MBB,
                                    const TargetRegisterInfo *TRI) {
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

      MachineBasicBlock::iterator Target = MBB.end();
      MachineBasicBlock::iterator It(MI);
      for (unsigned N = 0; N != WindowSize && It != MBB.begin(); ++N) {
        --It;
        MachineInstr &Prev = *It;
        // A store may write the slot being loaded, and moving SP changes what
        // [sp+N] means.
        if (Prev.mayStore() || Prev.isCall() || Prev.isTerminator() ||
            Prev.isInlineAsm() || Prev.hasUnmodeledSideEffects() ||
            Prev.modifiesRegister(RL78::SPreg, TRI))
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
      for (unsigned N = 0; N != WindowSize && It != MBB.begin(); ++N) {
        --It;
        MachineInstr &Prev = *It;
        if (Prev.isCall() || Prev.isTerminator() || Prev.isInlineAsm() ||
            Prev.hasUnmodeledSideEffects())
          break;
        // Stop at whatever produced the value being copied.
        if (Prev.modifiesRegister(RL78::RP0, TRI))
          break;
        if (Prev.readsRegister(Dst, TRI) || Prev.modifiesRegister(Dst, TRI))
          break;
        if (Prev.mayStore())
          SawStore = true;
        Target = It;
      }

      // Only worth it if it frees AX for a store that would otherwise exchange.
      if (Target != MBB.end() && SawStore) {
        MBB.splice(Target, &MBB, MachineBasicBlock::iterator(MI));
        Changed = ChangedAny = true;
        break;
      }
    }
  }
  return ChangedAny;
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
      if (!MBB.empty())
        moveLoadToWhereAXIsDead(MBB, TRI);

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
      case RL78::MOV_r_imm:
        assert(MI.getOperand(1).isImm());
        // Replace mov X, A + mov A, #0 with shrw AX, 8.
        if ((MI.getOperand(0).getReg() == RL78::R1) &&
            (MI.getOperand(1).getImm() == 0) &&
            (MachineBasicBlock::iterator(MI) != MBB.begin())) {
          MachineInstr &MI2 = *std::prev(MachineBasicBlock::iterator(MI));
          if ((MI2.getOpcode() == RL78::MOV_r_A) &&
              (MI2.getOperand(0).getReg() == RL78::R0)) {
            assert(MI2.getOperand(1).getReg() == RL78::R1);
            // Build the SHRW instruction.
            BuildMI(MBB, MI, DL, TII->get(RL78::SHRW_rp_i), RL78::RP0)
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
      case RL78::MOVW_rp_imm:
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
                    .add(MI.getOperand(0));
                MI.eraseFromParent();
              }
            }
          }
        }
        break;
      case RL78::SHL_r_imm:
        // Replace MOV R1, (R2/R3) + SHL R2/R3, #imm + MOV (R2/R3), R1 with SHL R2/R3, #imm.
        if ( MI.getOperand(0).getReg() == RL78::R1 &&
            (MachineBasicBlock::iterator(MI) != MBB.begin()) &&
            (MachineBasicBlock::iterator(MI) != MBB.end()) &&
            (std::prev(MachineBasicBlock::iterator(MI)) != MBB.begin()) &&
            (std::next(MachineBasicBlock::iterator(MI)) != MBB.end())) {
          MachineInstr &MI2 = *std::prev(MachineBasicBlock::iterator(MI));
          MachineInstr &MI3 = *std::next(MachineBasicBlock::iterator(MI));
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
      case RL78::SHLW_rp_imm:
        RemoveMOVWs(MI, MBB, Next, RL78::RP2);
        break;
      case RL78::SUBW_rp_rp: {
        // SUBW ax, ax is not permitted.
        if (MI.getOperand(2).getReg() == RL78::RP0 &&
            MI.getOperand(1).getReg() == MI.getOperand(2).getReg()) {
          BuildMI(MBB, MI, DL, TII->get(RL78::CLRW_rp))
              .addReg(MI.getOperand(0).getReg());
          MI.eraseFromParent();
        }
        break;
      }
      case RL78::AND_r_r: // Generated during lowering of AND16_rp_rp.
      case RL78::OR_r_r:  // Generated during lowering of OR16_rp_rp.
      case RL78::XOR_r_r: // Generated during lowering of XOR16_rp_rp.
        if (MI.getOperand(0).getReg() != RL78::R1)
          insert8BitExchange(MI, 0, DL, MBB, TII, isALive);
        break;
      case RL78::XCH_A_r:
      case RL78::MOV_A_PSW:
      case RL78::MOV_PSW_A:
        insert8BitExchange(MI, 0, DL, MBB, TII, isALive);
        break;
      case RL78::CLRB_r:
        // Replace MOV X, A + CLRB A with SHRW AX.
        if (MachineBasicBlock::iterator(MI) != MBB.begin()) {
          MachineInstr &MI2 = *std::prev(MachineBasicBlock::iterator(MI));
          if ((MI.getOperand(0).getReg() == RL78::R1) &&
              (MI2.getOpcode() == RL78::MOV_r_A) &&
              (MI2.getOperand(0).getReg() == RL78::R0)) {
            assert(MI2.getOperand(1).getReg() == RL78::R1);
            // Build the SHRW instruction.
            BuildMI(MBB, MI, DL, TII->get(RL78::SHRW_rp_i), RL78::RP0)
                .addReg(RL78::RP0, RegState::Kill).addImm(8);
            // Remove the MOV and CLRB instructions.
            MI.eraseFromParent();
            MI2.eraseFromParent();
          }
        }
        break;
      case RL78::CMP_r_memri:
        // MI.dump();
        assert(MI.getOperand(0).getReg() == RL78::R1);
        assert(MI.getOperand(4).getReg() == RL78::CCreg);
        // MI.getOperand(4).dump();
        // Replace MOV A, X + CMP A, [HL+byte] with CMPS X, [HL+byte].
        //
        // ExpandPostRAPseudos has already turned the copy feeding A into a real
        // MOV_A_r, so matching RL78::COPY here would never fire.
        {
          auto AAfter = ALiveAfterMI.find(&MI);
          bool ADeadAfter =
              (AAfter != ALiveAfterMI.end()) ? !AAfter->second : false;
          if (ADeadAfter && (MachineBasicBlock::iterator(MI) != MBB.begin()) &&
              (!MI.getOperand(4).isDead()) && !CCLiveOut) {
            MachineInstr &MI2 = *std::prev(MachineBasicBlock::iterator(MI));
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
                BuildMI(MBB, MI, DL, TII->get(RL78::CMPS_r_memri))
                    .add(MI2.getOperand(1))
                    .add(MI.getOperand(1))
                    .add(MI.getOperand(2))
                    .add(MI.getOperand(3));
                // Erase the MOV and CMP instructions.
                MI.eraseFromParent();
                MI2.eraseFromParent();
                // MBB.dump();
              }
            }
          }
        }
        break;
      case RL78::ADDW_rp_imm:
        // INCW/DECW instructions don't update the CCreg.
        if (!MI.getOperand(3).isDead())
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
              .add(MI.getOperand(1));
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
              .add(MI.getOperand(1));
          BuildMI(MBB, MI, DL, TII->get(RL78::DECW_rp))
              .add(MI.getOperand(0))
              .add(MI.getOperand(1));
          // Erase the ADDW instruction.
          MI.eraseFromParent();
        }
        break;
      case RL78::LOAD16_rp_stack_slot:
      case RL78::BSWAP_rp:
        insert16BitExchange(MI, 0, DL, MBB, TII, isALive || isXLive);
        break;
      case RL78::LOAD8_r_stack_slot:
        insert8BitExchange(MI, 0, DL, MBB, TII, isALive);
        break;
      case RL78::STORE16_stack_slot_rp:
        if (!ReplaceStoreWithPush(MI, MBB, DL, TII)) {
          insert16BitExchange(MI, 2, DL, MBB, TII, isALive || isXLive);
        }
        break;
      case RL78::STORE8_stack_slot_r:
        insert8BitExchange(MI, 2, DL, MBB, TII, isALive);
        break;
      case RL78::LOAD8_r_abs16:
        if (!RL78::RL78LowRegClass.contains(MI.getOperand(0).getReg()))
          insert8BitExchange(MI, 0, DL, MBB, TII, isALive);
        break;
      case RL78::LOAD8_rlo_saddr:
        if (!RL78::RL78LowRegClass.contains(MI.getOperand(0).getReg()))
          insert8BitExchange(MI, 0, DL, MBB, TII, isALive);
        break;
      case RL78::MOV_r_esaddr16:
        if (!RL78::RL78LowRegClass.contains(MI.getOperand(0).getReg()))
          insert8BitExchange(MI, 0, DL, MBB, TII, isALive);
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
      case RL78::CMPW_rp_imm:
        assert(MI.getOperand(0).isReg());
        assert(MI.getOperand(1).isImm());
        if (MI.getOperand(1).getImm() == 0) {
          if (Next == MBB.end())
            break;
          MachineInstr &MI1 = *Next;
          if (std::next(Next) == MBB.end())
            break;
          MachineInstr &MI2 = *std::next(Next);
          if ((MI1.getOpcode() == RL78::XOR1_cy_r) &&
              MI1.getOperand(0).isKill() &&
              (MI2.getOpcode() == RL78::BRCC) &&
              ((MI2.getOperand(1).getImm() == RL78CC::RL78CC_H) ||
                (MI2.getOperand(1).getImm() == RL78CC::RL78CC_NH))) {
            ++Next;
            ++Next;
            BuildMI(MBB, MI, DL, TII->get(RL78::ADDW_rp_rp))
                .addReg(RL78::RP0, RegState::DefineNoRead)
                .addReg(RL78::RP0, RegState::Kill)
                .addReg(RL78::RP0, RegState::Kill);
              MI.eraseFromParent();
              MI1.eraseFromParent();
          }
        }
        break;
      case RL78::CMP_r_r:
      case RL78::CMPW_rp_rp:
        // Besides the DAGCombiner (which we sort out during ISel) the
        // register coalescer can cause such this to happen as well
        // see gcc.c_torture\scal-to-vec1.c.
        if (MI.getOperand(0).getReg() == MI.getOperand(1).getReg()) {
          // Remove or replace branch with unconditional branch.
          // OBS. We only handle the cases where a BRCC appears immediately
          // after the CMP/CMPW, or after non-branch instruction(s):
          //   CMPW rp0, rp0
          //   BRCC
          // or:
          //   CMPW rp0, rp0
          //   <one or more non-branch instructions> e.g. rp0 = MOVW_AX_rp rp2
          //   BRCC
          // we can't have XOR1 instructions since this is not
          // caused by the DAGCombiner.
          while (Next != MBB.end() && Next->isDebugInstr())
              ++Next;
          // Save the position of the next instruction so that when looking
          // after LowCMPW_rp_rp, we won't skip other instructions that need
          // to be handled e.g. LOAD16_rp_stack_slot
          auto OrgNext = Next;
          auto handled = false;

          if (Next != MBB.end()) {
            while (Next->getOpcode() != RL78::BRCC &&
                   Next->getOpcode() != RL78::LowCMPW_rp_rp)
              ++Next;

            // We don't handle LowCMPW_rp_rp here.
            if (Next->getOpcode() == RL78::LowCMPW_rp_rp)
              Next = OrgNext;
            if (Next->getOpcode() == RL78::BRCC) {
              MachineInstr &MI2 = *Next++;

              // If the condition is true.
              if ((MI2.getOperand(1).getImm() == RL78CC::RL78CC_Z) ||
                  (MI2.getOperand(1).getImm() == RL78CC::RL78CC_NH) ||
                  (MI2.getOperand(1).getImm() == RL78CC::RL78CC_NC))
                BuildMI(MBB, MI2, DL, TII->get(RL78::BR)).add(MI2.getOperand(0));
              MI2.eraseFromParent();
              MI.eraseFromParent();
              handled = true;
            }
          }

          if (!handled) {
              bool foundLowCMP = false;
              // Later note: it seems it's not enough to look for the LowCMP insn
              // in the current MBB, so extend the search to the single successors
              // (by fallthrough or unconditional branch)
              auto pMBB = &MBB;
          next_MBB:
              while (Next != pMBB->end()) {
                if (Next->getOpcode() == RL78::LowCMPW_rp_rp) {
                  foundLowCMP = true;
                  break;
                }
                Next++;
              }
              if (!foundLowCMP) {
                auto nextMBB = pMBB->getFallThrough();
                if (!nextMBB && pMBB->getSingleSuccessor() && pMBB->getFirstInstrTerminator()->isUnconditionalBranch())
                  nextMBB = pMBB->getSingleSuccessor();
                if ((pMBB = nextMBB)) {
                  Next = pMBB->SkipPHIsLabelsAndDebug(pMBB->begin());
                  goto next_MBB;
                }
              }

              // Since the high parts are equal (AX == AX) in a 32 bit compare
              // our result can be based on the low part compare alone.
              if (foundLowCMP) {
                // Check first if we didn't do this already coming from another predecessor
                // (if so, nullify pMBB to indicate the condition)
                if (Next != pMBB->begin()) {
                  auto Prev = Next; --Prev;
                  if (Prev->getOpcode() == RL78::CMPW_rp_rp &&
                      Prev->getOperand(0).isIdenticalTo(Next->getOperand(0)) &&
                      Prev->getOperand(1).isIdenticalTo(Next->getOperand(1)))
                    pMBB = nullptr;
                }
                // If ok (first go)
                if (pMBB) {
                  BuildMI(*pMBB, Next, DL, TII->get(RL78::CMPW_rp_rp))
                      .add(Next->getOperand(0))
                      .add(Next->getOperand(1));
                }
                // Remove the cmpw ax, ax anyway
                MI.eraseFromParent();
                // Continue with the next original instruction
                Next = OrgNext;
              } else {
                report_fatal_error("cmpw ax, ax is not permitted");
              }
          }
        }
        break;
      case RL78::XOR1_cy_r:
      case RL78::XOR1_cy_A:
        // Undo RP0 liveness hack
        if (MI.getOperand(0).getReg() == RL78::RP0) {
          BuildMI(MBB, MI, DL, TII->get(MI.getOpcode()))
              .addReg(RL78::R1, MI.getOperand(0).isKill() ? RegState::Kill : 0)
              .add(MI.getOperand(1));
          MI.eraseFromParent();
        }
      }
    }
  }

  // steps to handle [hl] only instructions where [de] was used
  LLVM_DEBUG(MF.dump());
  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;

    for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end();
         Next != E;) {
      MachineInstr &MI = *Next;
      DebugLoc DL = MI.getDebugLoc();
      ++Next;
      switch (MI.getOpcode()) {
      default:
        continue;
      case RL78::STORE8_memrr_r:
      case RL78::INC_memri:
      case RL78::DEC_memri:
      case RL78::INCW_memri:
      case RL78::DECW_memri:
        insertHLExchange(MI, 0, DL, MBB, TII);
        break;
      case RL78::STORE8_ri_imm:
      case RL78::STORE8_ri_r:
      case RL78::STORE16_rpi_rp:
        if (MI.getOperand(0).getReg() != RL78::RP2 &&
            MI.getOperand(0).getReg() != RL78::RP4)
          insertHLExchange(MI, 0, DL, MBB, TII);
        break;
      case RL78::CMP_r_memri:
      case RL78::CMP_r_memrr:
      case RL78::CMPW_rp_memri:
      case RL78::LowCMPW_rp_memri:
      case RL78::LOAD8_r_memrr:
        insertHLExchange(MI, 1, DL, MBB, TII);
        break;
        case RL78::LOAD16_rp_rpi:
        case RL78::LOAD8_r_ri:
        if (MI.getOperand(1).getReg() != RL78::RP2 &&
            MI.getOperand(1).getReg() != RL78::RP4)
          insertHLExchange(MI, 1, DL, MBB, TII);
        break;
      case RL78::ADD_r_memrr:
      case RL78::SUB_r_memrr:
      case RL78::ADDC_r_memri:
      case RL78::SUBC_r_memri:
      case RL78::AND_r_memrr:
      case RL78::OR_r_memrr:
      case RL78::XOR_r_memrr:
      case RL78::ADD_r_memri:
      case RL78::SUB_r_memri:
      case RL78::AND_r_memri:
      case RL78::OR_r_memri:
      case RL78::XOR_r_memri:
      case RL78::CMPW_rp_esmemHLi:
      case RL78::ADDW_rp_memri:
      case RL78::SUBW_rp_memri:
        insertHLExchange(MI, 2, DL, MBB, TII);
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
      // if this wasn't the last instruction in BB
      if (Next != MBB.end()) {
        MachineInstr &MI2 = *Next;
        
        // if the 2 opcodes are equal, XCH/XCHW instructions using the same
        // registers(first one is A anyways)
        if ((MI1.getOpcode() == MI2.getOpcode()) &&
            ((MI1.getOpcode() == RL78::XCH_A_r) ||
             ((MI1.getOpcode() == RL78::XCHW_AX_rp))) &&
            (MI1.getOperand(1).getReg() == MI2.getOperand(1).getReg())) {
          // update iterator
          ++Next;
          // remove them both
          MI1.eraseFromParent();
          MI2.eraseFromParent();
        } else if ((MI2.getOpcode() == RL78::COPY) &&
                   (MI2.getOperand(1).isKill()) &&
                   (((MI1.getOpcode() == RL78::XCH_A_r) &&
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
          if ((Next != MBB.end())) {
            MachineInstr &MI3 = *Next;
            if ((MI3.getOpcode() == RL78::MOVW_rp_sp) &&
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
  LLVM_DEBUG(MF.dump());
  return true;
}
