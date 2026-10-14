//===-- RL78LateReorder.cpp - Reorder instructions before emission --------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Changes the order of instructions where the order the earlier passes left
// costs exchanges or clocks.
//
// A 16-bit AND, OR or XOR is the byte operation on A (the high byte of AX)
// and, with XCH A, X around it, on X. Two in a row keep both exchanges in the
// middle, although they cancel:
//
//   XOR A, B          ->  XOR A, B
//   XCH A, X              AND A, D
//   XOR A, C              XCH A, X
//   XCH A, X              XOR A, C
//   AND A, D              AND A, E
//   XCH A, X              XCH A, X
//   AND A, E
//   XCH A, X
//
// Any operation that writes only A (and the flags) and reads no other byte
// of AX works on one byte of AX without regard to the other, so a run of them
// and of XCH A, X can do all the work on one byte, exchange, and do the work
// on the other. Instructions in the run that touch neither A, X nor the flags
// go as early as the registers they share with the operations allow, and
// where one has to stay between two operations on a byte the run needs more
// exchanges.
//
// An instruction that forms an address with a register the instruction
// before it wrote waits a clock (manual 7.2.3): MOVW HL, SP before
// [HL+byte], INCW DE before [DE], POP before RET. Where the writer can change
// places with the independent instruction before it, or the user with the
// one after it, and that leaves fewer such pairs, they do. Not in functions
// optimized for size, where the order only perturbs the outliner.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78InstrInfo.h"
#include "RL78Subtarget.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/LiveRegUnits.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"

#define DEBUG_TYPE "rl78-late-reorder"
using namespace llvm;

STATISTIC(NumHazards, "Number of address hazards moved apart");
STATISTIC(NumExchanges,
          "Number of XCH A, X removed by regrouping byte operations");

namespace {
class RL78LateReorder : public MachineFunctionPass {
public:
  static char ID;
  RL78LateReorder() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override { return "RL78 late reordering"; }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties().setNoVRegs();
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  const RL78InstrInfo *TII = nullptr;
  const TargetRegisterInfo *TRI = nullptr;

  enum Kind { Other, Exchange, OnA, Aside };
  Kind classify(const MachineInstr &MI) const;
  bool regroup(MachineBasicBlock &MBB, MachineBasicBlock::iterator Begin,
               MachineBasicBlock::iterator End);
  bool regroupExchanges(MachineBasicBlock &MBB);

  bool hazard(const MachineInstr *Def, const MachineInstr *Use) const;
  bool canSwap(const MachineInstr &A, const MachineInstr &B) const;
  bool avoidHazards(MachineBasicBlock &MBB);
};
} // end anonymous namespace

char RL78LateReorder::ID = 0;

INITIALIZE_PASS(RL78LateReorder, DEBUG_TYPE, "RL78 late reordering", false,
                false)

FunctionPass *llvm::createRL78LateReorderPass() {
  return new RL78LateReorder();
}

// An instruction that conditionally skips the next one: nothing may come
// between the two.
static bool isSkip(const MachineInstr &MI) {
  switch (MI.getOpcode()) {
  case RL78::SKcc:
  case RL78::SKHcc:
  case RL78::SKcc_cg:
  case RL78::SKHcc_cg:
  case RL78::Bcc_over:
    return true;
  }
  return false;
}

// Exchange: XCH A, X. OnA: computes A from A and from registers and memory
// outside AX, and writes nothing but A and the flags. Aside: reads and writes
// neither A, X nor the flags, and stores nothing. Other: everything else,
// which ends a run; among it what moves SP, since a load from the stack must
// not move to where its slot is free (an interrupt may overwrite it).
RL78LateReorder::Kind RL78LateReorder::classify(const MachineInstr &MI) const {
  if (MI.getOpcode() == RL78::XCH_A_X)
    return Exchange;
  if (MI.isBundle() || MI.isCall() || MI.isTerminator() || MI.isInlineAsm() ||
      MI.isPseudo() || isSkip(MI) || MI.mayStore() ||
      MI.hasUnmodeledSideEffects() || MI.hasOrderedMemoryRef() ||
      MI.modifiesRegister(RL78::SPreg, TRI))
    return Other;
  bool TouchesAX = false, ReadsFlags = false, WritesOther = false;
  for (const MachineOperand &MO : MI.operands()) {
    if (MO.isRegMask())
      return Other;
    if (!MO.isReg() || !MO.getReg())
      continue;
    Register R = MO.getReg();
    if (R == RL78::CCreg) {
      ReadsFlags |= MO.readsReg();
      TouchesAX = true;
      continue;
    }
    if (!TRI->regsOverlap(R, RL78::RP0)) {
      WritesOther |= MO.isDef();
      continue;
    }
    TouchesAX = true;
    // Only A, written and read in place.
    if (R != RL78::R1)
      return Other;
  }
  if (!TouchesAX)
    return Aside;
  if (ReadsFlags || WritesOther || !MI.modifiesRegister(RL78::R1, TRI))
    return Other;
  return OnA;
}

// [Begin, End) holds exchanges, operations on A and instructions aside, and
// starts with an exchange or an operation on A. Schedule it again: first
// what is aside and ready, then the operations on the byte in A that are
// ready, and an exchange only when nothing else is; then an exchange if the
// bytes would not end where they did. Keep the new order if it has fewer
// exchanges and leaves the same flags.
bool RL78LateReorder::regroup(MachineBasicBlock &MBB,
                              MachineBasicBlock::iterator Begin,
                              MachineBasicBlock::iterator End) {
  // The byte an operation works on, as the number of exchanges before it
  // (mod 2); -1 for an instruction aside.
  SmallVector<std::pair<MachineInstr *, int>, 16> Items;
  SmallVector<MachineInstr *, 8> Exchanges, Debug;
  MachineInstr *LastFlags = nullptr;
  bool Parity = false;
  for (MachineInstr &MI : make_range(Begin, End)) {
    if (MI.isDebugInstr()) {
      Debug.push_back(&MI);
      continue;
    }
    switch (classify(MI)) {
    case Exchange:
      Exchanges.push_back(&MI);
      Parity = !Parity;
      break;
    case OnA:
      Items.push_back({&MI, Parity});
      if (MI.modifiesRegister(RL78::CCreg, TRI))
        LastFlags = &MI;
      break;
    case Aside:
      Items.push_back({&MI, -1});
      break;
    case Other:
      llvm_unreachable("not in a run");
    }
  }
  // Each byte needs at most one exchange to reach it and one back.
  if (Exchanges.size() < 2)
    return false;

  auto Writes = [&](const MachineInstr &Def, const MachineInstr &Use) {
    for (const MachineOperand &D : Def.all_defs())
      for (const MachineOperand &U : Use.all_uses())
        if (TRI->regsOverlap(D.getReg(), U.getReg()))
          return true;
    return false;
  };
  // Item J has to stay behind item I < J: two operations on one byte, two
  // instructions aside, or an instruction aside that writes what the other
  // reads (the operations write only A and the flags, which nothing aside
  // touches).
  auto Depends = [&](unsigned I, unsigned J) {
    auto [A, ByteA] = Items[I];
    auto [B, ByteB] = Items[J];
    if (ByteA >= 0 && ByteB >= 0)
      return ByteA == ByteB;
    if (ByteA < 0 && ByteB < 0)
      return true;
    return Writes(*A, *B) || Writes(*B, *A);
  };
  unsigned N = Items.size();
  SmallVector<BitVector, 16> Before(N, BitVector(N));
  for (unsigned J = 0; J != N; ++J)
    for (unsigned I = 0; I != J; ++I)
      Before[J][I] = Depends(I, J);

  // The new order; ~0u stands for an exchange.
  SmallVector<unsigned, 24> Order;
  BitVector Done(N);
  int Byte = 0;
  unsigned NumUsed = 0;
  auto Ready = [&](unsigned J) { return !Done[J] && !Before[J].test(Done); };
  while (Done.count() != N) {
    unsigned Pick = N;
    for (unsigned J = 0; J != N && Pick == N; ++J)
      if (Items[J].second < 0 && Ready(J))
        Pick = J;
    for (unsigned J = 0; J != N && Pick == N; ++J)
      if (Items[J].second == Byte && Ready(J))
        Pick = J;
    if (Pick == N) {
      Order.push_back(~0u);
      Byte = !Byte;
      ++NumUsed;
      continue;
    }
    Done.set(Pick);
    Order.push_back(Pick);
  }
  if (Byte != Parity) {
    Order.push_back(~0u);
    ++NumUsed;
  }
  if (NumUsed >= Exchanges.size())
    return false;

  // The flags after the run come from its last operation that sets them;
  // when they are read, that operation has to stay last.
  if (LastFlags) {
    MachineInstr *NewLast = nullptr;
    for (unsigned I : Order)
      if (I != ~0u && Items[I].first->modifiesRegister(RL78::CCreg, TRI))
        NewLast = Items[I].first;
    if (NewLast != LastFlags && TII->isLiveBefore(MBB, End, RL78::CCreg))
      return false;
  }

  // Emit in the new order in front of End. A debug value in the run is
  // moved behind it, and loses its location if that is in AX.
  auto Place = [&](MachineInstr *MI) { MBB.splice(End, &MBB, MI); };
  unsigned Used = 0;
  for (unsigned I : Order)
    Place(I == ~0u ? Exchanges[Used++] : Items[I].first);
  for (unsigned I = Used; I != Exchanges.size(); ++I)
    Exchanges[I]->eraseFromParent();
  for (MachineInstr *MI : Debug) {
    for (MachineOperand &MO : MI->debug_operands())
      if (MO.isReg() && MO.getReg() && TRI->regsOverlap(MO.getReg(), RL78::RP0))
        MO.setReg(Register());
    Place(MI);
  }
  NumExchanges += Exchanges.size() - Used;
  return true;
}

bool RL78LateReorder::regroupExchanges(MachineBasicBlock &MBB) {
  bool Changed = false;
  MachineBasicBlock::iterator I = MBB.begin(), E = MBB.end();
  while (I != E) {
    // A run starts with an exchange or an operation on A that is not the
    // instruction a skip skips.
    Kind K = I->isDebugInstr() ? Other : classify(*I);
    if ((K != Exchange && K != OnA) ||
        (I != MBB.begin() && isSkip(*prev_nodbg(I, MBB.begin())))) {
      ++I;
      continue;
    }
    MachineBasicBlock::iterator Begin = I, Last = I;
    for (++I; I != E; ++I) {
      if (I->isDebugInstr())
        continue;
      Kind Next = classify(*I);
      if (Next == Other)
        break;
      if (Next != Aside)
        Last = I;
    }
    // The run ends with its last exchange or operation; what is aside after
    // it stays where it is.
    MachineBasicBlock::iterator End = std::next(Last);
    if (regroup(MBB, Begin, End))
      Changed = true;
    I = End;
  }
  return Changed;
}

// Does \p Use form an address with a register \p Def writes? BC, DE, HL and
// their halves in an instruction that reads or writes memory (A, X and AX
// carry the data, PUSH stores its register), SP in one that addresses the
// stack.
bool RL78LateReorder::hazard(const MachineInstr *Def,
                             const MachineInstr *Use) const {
  if (!Def || !Use || Def->isDebugInstr() || Use->isDebugInstr())
    return false;
  bool Stack = Use->mayLoadOrStore() || Use->isCall() || Use->isReturn();
  bool Memory = Use->mayLoadOrStore() && Use->getOpcode() != RL78::PUSH_rp;
  for (const MachineOperand &MO : Use->all_uses()) {
    Register R = MO.getReg();
    if (!R || MO.isUndef())
      continue;
    bool Address = R == RL78::SPreg
                       ? Stack
                       : Memory && R != RL78::CCreg &&
                             !TRI->regsOverlap(R, RL78::RP0) &&
                             (RL78::RL78RegRegClass.contains(R) ||
                              RL78::RL78RPRegsRegClass.contains(R));
    if (Address && Def->modifiesRegister(R, TRI))
      return true;
  }
  return false;
}

// May \p A and the instruction \p B right after it change places?
bool RL78LateReorder::canSwap(const MachineInstr &A,
                              const MachineInstr &B) const {
  for (const MachineInstr *MI : {&A, &B})
    if (MI->isDebugInstr() || MI->isMetaInstruction() || MI->isBundle() ||
        MI->isCall() || MI->isTerminator() || MI->isBranch() ||
        MI->isInlineAsm() || isSkip(*MI) || MI->hasUnmodeledSideEffects() ||
        MI->hasOrderedMemoryRef())
      return false;
  auto Overlap = [&](const MachineInstr &X, const MachineInstr &Y) {
    for (const MachineOperand &D : X.operands()) {
      if (D.isRegMask())
        return true;
      if (!D.isReg() || !D.isDef() || !D.getReg())
        continue;
      for (const MachineOperand &O : Y.operands())
        if (O.isRegMask() || (O.isReg() && O.getReg() &&
                              TRI->regsOverlap(D.getReg(), O.getReg())))
          return true;
    }
    return false;
  };
  if (Overlap(A, B) || Overlap(B, A))
    return false;
  if (A.mayLoadOrStore() && B.mayLoadOrStore() &&
      (A.mayStore() || B.mayStore()) &&
      A.mayAlias(static_cast<AAResults *>(nullptr), B,
                 /*UseTBAA=*/false))
    return false;
  return true;
}

bool RL78LateReorder::avoidHazards(MachineBasicBlock &MBB) {
  // How far an instruction may come from to fill the gap.
  const unsigned Window = 4;
  bool Changed = false;
  auto Prev = [&](MachineInstr *MI) -> MachineInstr * {
    MachineBasicBlock::iterator I(MI);
    if (I == MBB.begin())
      return nullptr;
    MachineBasicBlock::iterator P = prev_nodbg(I, MBB.begin());
    return P->isDebugInstr() ? nullptr : &*P;
  };
  auto Next = [&](MachineInstr *MI) -> MachineInstr * {
    MachineBasicBlock::iterator N =
        next_nodbg(MachineBasicBlock::iterator(MI), MBB.end());
    return N == MBB.end() ? nullptr : &*N;
  };
  // The instruction a skip skips stays where it is.
  auto Skipped = [&](MachineInstr *MI) {
    MachineInstr *P = Prev(MI);
    return P && isSkip(*P);
  };
  // Is it better to take X from where it is to between D and U? It must
  // change places with everything on its way, and leave fewer hazards.
  auto Better = [&](MachineInstr *X, MachineInstr *D, MachineInstr *U) {
    MachineInstr *XP = Prev(X), *XN = Next(X);
    int Before = hazard(XP, X) + hazard(X, XN) + 1;
    int After = hazard(XP, XN) + hazard(D, X) + hazard(X, U);
    // X next to D or U: the pairs overlap.
    if (XN == D)
      After = hazard(XP, D) + hazard(D, X) + hazard(X, U),
      Before = hazard(XP, X) + hazard(X, D) + 1;
    if (XP == U)
      After = hazard(D, X) + hazard(X, U) + hazard(U, XN),
      Before = 1 + hazard(U, X) + hazard(X, XN);
    return After < Before;
  };
  for (MachineBasicBlock::iterator I = MBB.begin(), E = MBB.end(); I != E;
       I = std::next(I)) {
    MachineInstr *U = &*I;
    MachineInstr *D = Prev(U);
    if (U->isDebugInstr() || !hazard(D, U) || Skipped(U))
      continue;
    MachineInstr *Fill = nullptr;
    // From above: X moves down past everything up to D.
    SmallVector<MachineInstr *, 4> Crossed{D};
    for (MachineInstr *X = Prev(D); X && !Fill && Crossed.size() <= Window;
         X = Prev(X)) {
      if (!Skipped(X) &&
          all_of(Crossed, [&](MachineInstr *Y) { return canSwap(*X, *Y); }) &&
          Better(X, D, U))
        Fill = X;
      Crossed.push_back(X);
    }
    // From below: X moves up past everything down to U.
    Crossed.assign({U});
    for (MachineInstr *X = Next(U); X && !Fill && Crossed.size() <= Window;
         X = Next(X)) {
      if (!Skipped(X) &&
          all_of(Crossed, [&](MachineInstr *Y) { return canSwap(*Y, *X); }) &&
          Better(X, D, U))
        Fill = X;
      Crossed.push_back(X);
    }
    if (!Fill)
      continue;
    MBB.splice(MachineBasicBlock::iterator(U), &MBB,
               MachineBasicBlock::iterator(Fill));
    ++NumHazards;
    Changed = true;
  }
  return Changed;
}

bool RL78LateReorder::runOnMachineFunction(MachineFunction &MF) {
  if (skipFunction(MF.getFunction()))
    return false;
  TII = static_cast<const RL78InstrInfo *>(MF.getSubtarget().getInstrInfo());
  TRI = MF.getSubtarget().getRegisterInfo();
  bool Changed = false;
  bool Hazards = !MF.getFunction().hasOptSize();
  for (MachineBasicBlock &MBB : MF) {
    bool BlockChanged = regroupExchanges(MBB);
    if (Hazards)
      BlockChanged |= avoidHazards(MBB);
    // Two instructions that read a register may have changed places: the
    // kill flags as well as the exchanges' flags.
    if (BlockChanged)
      TII->setExchangeFlags(MBB);
    Changed |= BlockChanged;
  }
  return Changed;
}
