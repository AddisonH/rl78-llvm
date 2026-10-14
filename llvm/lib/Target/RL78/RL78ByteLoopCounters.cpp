//===- RL78ByteLoopCounters.cpp - Count loops with DEC and BNZ -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// A loop that runs a number of times known on entry needs its counter only
// to stop. In 16 bits that costs, every iteration, a decrement and a test
// that goes through AX, because DECW sets no flags:
//
//     decw bc; movw ax, bc; or a, x; bnz $loop
//
// and AX is usually what the loop computes in, so it is saved around the
// test as well. DEC of a byte register sets Z. Count in two bytes instead:
//
//     dec c; bnz $loop; dec b; bnz $loop
//
// The second pair runs once in 256 iterations. With m the number of times
// the loop branches back, the low counter starts at (m & 0xff) + 1 and the
// high one at (m >> 8) + 1; a zero low counter runs 256 times. A loop known
// to run at most 256 times needs the low counter only.
//
// This is done where the old counter then has no use left: it is used by its
// own increment and by the comparison that ends the loop, nothing else.
// Two counters take three bytes more than the 16-bit one, so a function
// that is optimized for size gets the single byte counter only.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/Transforms/Utils/Local.h"
#include "llvm/Transforms/Utils/ScalarEvolutionExpander.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-byte-loop-counters"

STATISTIC(NumByteCounters, "Number of loops counted in bytes");

static cl::opt<bool>
    EnableByteCounters("rl78-byte-counters", cl::Hidden, cl::init(true),
                       cl::desc("Count loops whose counter has no other use "
                                "with DEC and BNZ on byte registers"));

static cl::opt<unsigned>
    MaxLoopSize("rl78-byte-counters-max-loop-size", cl::Hidden, cl::init(30),
                cl::desc("The largest loop, in IR instructions, that is "
                         "counted in bytes"));

namespace {

class RL78ByteLoopCounters : public FunctionPass {
public:
  static char ID;
  RL78ByteLoopCounters() : FunctionPass(ID) {}

  StringRef getPassName() const override { return "RL78 byte loop counters"; }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<LoopInfoWrapperPass>();
    AU.addRequired<ScalarEvolutionWrapperPass>();
    AU.addPreserved<LoopInfoWrapperPass>();
  }

  bool runOnFunction(Function &F) override;

private:
  bool convert(Loop &L, LoopInfo &LI, ScalarEvolution &SE);
};

} // end anonymous namespace

char RL78ByteLoopCounters::ID = 0;

INITIALIZE_PASS_BEGIN(RL78ByteLoopCounters, DEBUG_TYPE,
                      "RL78 byte loop counters", false, false)
INITIALIZE_PASS_DEPENDENCY(LoopInfoWrapperPass)
INITIALIZE_PASS_DEPENDENCY(ScalarEvolutionWrapperPass)
INITIALIZE_PASS_END(RL78ByteLoopCounters, DEBUG_TYPE,
                    "RL78 byte loop counters", false, false)

FunctionPass *llvm::createRL78ByteLoopCountersPass() {
  return new RL78ByteLoopCounters();
}

// The counter that \p Cmp tests: a 16-bit header phi used by its increment
// and by \p Cmp only, the increment by the phi and \p Cmp only. Returns the
// increment as well.
static PHINode *getCounter(ICmpInst *Cmp, Loop &L, Instruction *&Inc) {
  for (Value *Op : Cmp->operands()) {
    auto *I = dyn_cast<Instruction>(Op);
    if (!I || !L.contains(I))
      continue;
    auto *Phi = dyn_cast<PHINode>(I);
    if (Phi) {
      // The comparison is of the phi: find the increment among its users.
      Inc = nullptr;
      for (User *U : Phi->users())
        if (U != Cmp)
          Inc = dyn_cast<Instruction>(U);
    } else {
      Inc = I;
      if (Inc->getNumOperands() != 2)
        return nullptr;
      Phi = dyn_cast<PHINode>(Inc->getOperand(0));
      if (!Phi)
        Phi = dyn_cast<PHINode>(Inc->getOperand(1));
    }
    if (!Phi || !Inc || Phi->getParent() != L.getHeader() ||
        !Phi->getType()->isIntegerTy(16) || !L.contains(Inc) ||
        Phi->getIncomingValueForBlock(L.getLoopLatch()) != Inc)
      return nullptr;
    auto OnlyUsedBy = [&](Instruction *V, Instruction *Other) {
      return all_of(V->users(),
                    [&](User *U) { return U == Other || U == Cmp; });
    };
    if (!OnlyUsedBy(Phi, Inc) || !OnlyUsedBy(Inc, Phi))
      return nullptr;
    return Phi;
  }
  return nullptr;
}

bool RL78ByteLoopCounters::convert(Loop &L, LoopInfo &LI,
                                   ScalarEvolution &SE) {
  BasicBlock *Preheader = L.getLoopPreheader();
  BasicBlock *Header = L.getHeader();
  BasicBlock *Latch = L.getLoopLatch();
  if (!Preheader || !Latch)
    return false;
  auto *Br = dyn_cast<CondBrInst>(Latch->getTerminator());
  if (!Br)
    return false;
  auto *Cmp = dyn_cast<ICmpInst>(Br->getCondition());
  if (!Cmp || !Cmp->hasOneUse())
    return false;
  BasicBlock *Exit = Br->getSuccessor(Br->getSuccessor(0) == Header ? 1 : 0);
  if (L.contains(Exit))
    return false;

  Instruction *Inc;
  PHINode *Counter = getCounter(Cmp, L, Inc);
  if (!Counter)
    return false;

  // The counters have to stay in registers to be worth it: a small loop
  // without calls. In a large one the counter is spilled, and a byte in a
  // stack slot is no easier to count down than a word.
  if (!L.isInnermost())
    return false;
  unsigned Size = 0;
  for (const BasicBlock *BB : L.blocks())
    for (const Instruction &I : *BB) {
      if (isa<CallBase>(I) && !isa<IntrinsicInst>(I))
        return false;
      ++Size;
    }
  if (Size > MaxLoopSize)
    return false;

  // How many times the latch branches back before it leaves the loop.
  const SCEV *Count = SE.getExitCount(&L, Latch);
  if (isa<SCEVCouldNotCompute>(Count) || !Count->getType()->isIntegerTy(16) ||
      !SE.isLoopInvariant(Count, &L))
    return false;
  SCEVExpander Expander(SE, "bytecount");
  if (!Expander.isSafeToExpandAt(Count, Preheader->getTerminator()))
    return false;
  // The count is what the old counter started from, or close to it: do not
  // compute more than that would have cost.
  if (!isa<SCEVConstant>(Count) && !isa<SCEVUnknown>(Count)) {
    const auto *Add = dyn_cast<SCEVAddExpr>(Count);
    if (!Add || Add->getNumOperands() != 2 ||
        !isa<SCEVConstant>(Add->getOperand(0)) ||
        !isa<SCEVUnknown>(Add->getOperand(1)))
      return false;
  }
  bool OneByte = SE.getUnsignedRangeMax(Count).ule(255);
  // Two counters are three bytes more than one of 16 bits (unless AX had to
  // be saved around its test, which is not known here).
  if (!OneByte && Header->getParent()->hasOptSize())
    return false;

  LLVM_DEBUG(dbgs() << "Counting loop " << Header->getName() << " in "
                    << (OneByte ? "one byte" : "two bytes") << ": " << *Count
                    << "\n");

  LLVMContext &Ctx = Header->getContext();
  Type *I8 = Type::getInt8Ty(Ctx);
  Value *M = Expander.expandCodeFor(Count, Count->getType(),
                                    Preheader->getTerminator());
  IRBuilder<> B(Preheader->getTerminator());
  Value *One = ConstantInt::get(I8, 1);
  Value *Lo0 = B.CreateAdd(B.CreateTrunc(M, I8), One, "count.lo");
  Value *Hi0 = nullptr;
  if (!OneByte)
    Hi0 = B.CreateAdd(B.CreateTrunc(B.CreateLShr(M, 8), I8), One, "count.hi");

  // The second latch, which the first reaches when the low counter is zero.
  BasicBlock *Latch2 = nullptr;
  if (!OneByte) {
    Latch2 = BasicBlock::Create(Ctx, Latch->getName() + ".hi",
                                Header->getParent(), Latch->getNextNode());
    L.addBasicBlockToLoop(Latch2, LI);
    for (PHINode &Phi : Header->phis())
      Phi.addIncoming(Phi.getIncomingValueForBlock(Latch), Latch2);
    for (PHINode &Phi : Exit->phis())
      for (unsigned I = 0, E = Phi.getNumIncomingValues(); I != E; ++I)
        if (Phi.getIncomingBlock(I) == Latch)
          Phi.setIncomingBlock(I, Latch2);
  }

  B.SetInsertPoint(Header, Header->begin());
  PHINode *Lo = B.CreatePHI(I8, 3, "lo");
  PHINode *Hi = OneByte ? nullptr : B.CreatePHI(I8, 3, "hi");

  Value *MinusOne = ConstantInt::getAllOnesValue(I8);
  Value *Zero = ConstantInt::get(I8, 0);
  B.SetInsertPoint(Br);
  Value *LoDec = B.CreateAdd(Lo, MinusOne, "lo.dec");
  B.CreateCondBr(B.CreateICmpEQ(LoDec, Zero), OneByte ? Exit : Latch2, Header);
  Lo->addIncoming(Lo0, Preheader);
  Lo->addIncoming(LoDec, Latch);
  if (!OneByte) {
    B.SetInsertPoint(Latch2);
    Value *HiDec = B.CreateAdd(Hi, MinusOne, "hi.dec");
    B.CreateCondBr(B.CreateICmpEQ(HiDec, Zero), Exit, Header);
    Lo->addIncoming(LoDec, Latch2);
    Hi->addIncoming(Hi0, Preheader);
    Hi->addIncoming(Hi, Latch);
    Hi->addIncoming(HiDec, Latch2);
  }

  SE.forgetLoop(&L);
  Br->eraseFromParent();
  Cmp->eraseFromParent();
  Counter->replaceAllUsesWith(PoisonValue::get(Counter->getType()));
  Inc->replaceAllUsesWith(PoisonValue::get(Inc->getType()));
  Inc->eraseFromParent();
  Counter->eraseFromParent();
  ++NumByteCounters;
  return true;
}

bool RL78ByteLoopCounters::runOnFunction(Function &F) {
  if (!EnableByteCounters || skipFunction(F))
    return false;
  LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
  ScalarEvolution &SE = getAnalysis<ScalarEvolutionWrapperPass>().getSE();
  bool Changed = false;
  for (Loop *L : LI.getLoopsInPreorder())
    Changed |= convert(*L, LI, SE);
  return Changed;
}
