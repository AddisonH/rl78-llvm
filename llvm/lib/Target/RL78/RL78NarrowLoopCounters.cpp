//===- RL78NarrowLoopCounters.cpp - Count loops in 16 bits ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// A loop counter declared wider than it needs to be (`for (int64_t i = 1;
// i <= 64; i++)`, or a long counting to 100) costs two or four registers on
// RL78 and an add-with-carry chain and a multi-word compare per iteration.
// Nothing upstream narrows an induction variable: IndVarSimplify only widens.
//
// Rebuild such a counter in i16 when it is used by nothing but its own
// constant-step increment and by compares against constants, and SCEV shows
// both the counter and its increment stay within 16 bits (signed or unsigned
// as each compare requires). Counters that also index memory are left alone,
// for LSR.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/PatternMatch.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/Transforms/Utils/Local.h"

using namespace llvm;
using namespace PatternMatch;

#define DEBUG_TYPE "rl78-narrow-loop-counters"

STATISTIC(NumNarrowed, "Number of loop counters narrowed to 16 bits");

static cl::opt<bool>
    EnableNarrowCounters("rl78-narrow-counters", cl::Hidden,
                         cl::init(true),
                         cl::desc("Count loops in 16 bits when the counter "
                                  "is only compared with constants"));

namespace {
class RL78NarrowLoopCounters : public FunctionPass {
public:
  static char ID;
  RL78NarrowLoopCounters() : FunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 narrow loop counters";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<LoopInfoWrapperPass>();
    AU.addRequired<ScalarEvolutionWrapperPass>();
    AU.addPreserved<LoopInfoWrapperPass>();
    AU.setPreservesCFG();
  }

  bool runOnFunction(Function &F) override;

private:
  bool narrow(PHINode &Phi, Loop &L, ScalarEvolution &SE);
};
} // end anonymous namespace

char RL78NarrowLoopCounters::ID = 0;

INITIALIZE_PASS_BEGIN(RL78NarrowLoopCounters, DEBUG_TYPE,
                      "RL78 narrow loop counters", false, false)
INITIALIZE_PASS_DEPENDENCY(LoopInfoWrapperPass)
INITIALIZE_PASS_DEPENDENCY(ScalarEvolutionWrapperPass)
INITIALIZE_PASS_END(RL78NarrowLoopCounters, DEBUG_TYPE,
                    "RL78 narrow loop counters", false, false)

FunctionPass *llvm::createRL78NarrowLoopCountersPass() {
  return new RL78NarrowLoopCounters();
}

// Whether every value of R, and C, survives truncation to 16 bits and
// compares the same way under Pred afterwards.
static bool fits16(const ConstantRange &R, const APInt &C,
                   CmpInst::Predicate Pred) {
  bool Unsigned = R.getUnsignedMax().getActiveBits() <= 16 &&
                  C.getActiveBits() <= 16;
  bool Signed = R.getSignedMin().getSignificantBits() <= 16 &&
                R.getSignedMax().getSignificantBits() <= 16 &&
                C.getSignificantBits() <= 16;
  if (ICmpInst::isEquality(Pred))
    return Unsigned || Signed;
  if (ICmpInst::isUnsigned(Pred))
    return Unsigned;
  return Signed;
}

bool RL78NarrowLoopCounters::narrow(PHINode &Phi, Loop &L,
                                    ScalarEvolution &SE) {
  auto *Ty = dyn_cast<IntegerType>(Phi.getType());
  if (!Ty || Ty->getBitWidth() <= 16 || Phi.getNumIncomingValues() != 2)
    return false;
  BasicBlock *Latch = L.getLoopLatch();
  BasicBlock *Preheader = L.getLoopPreheader();
  if (!Latch || !Preheader)
    return false;
  auto *Start = dyn_cast<ConstantInt>(Phi.getIncomingValueForBlock(Preheader));
  auto *Next = dyn_cast<BinaryOperator>(Phi.getIncomingValueForBlock(Latch));
  const APInt *Step;
  if (!Start || !Next || !L.contains(Next) ||
      !match(Next, m_c_Add(m_Specific(&Phi), m_APInt(Step))) ||
      Step->getSignificantBits() > 16)
    return false;

  // Only the increment and compares against constants may use the counter.
  SmallVector<ICmpInst *, 2> Cmps;
  auto UsesOK = [&](Instruction *V, Instruction *Other) {
    for (User *U : V->users()) {
      if (U == Other)
        continue;
      auto *Cmp = dyn_cast<ICmpInst>(U);
      if (!Cmp || !L.contains(Cmp) || !isa<ConstantInt>(Cmp->getOperand(1)) ||
          Cmp->getOperand(0) != V)
        return false;
      Cmps.push_back(Cmp);
    }
    return true;
  };
  if (!UsesOK(&Phi, Next) || !UsesOK(Next, &Phi))
    return false;

  ConstantRange PhiR = SE.getSignedRange(SE.getSCEV(&Phi))
                           .intersectWith(SE.getUnsignedRange(SE.getSCEV(&Phi)));
  ConstantRange NextR =
      SE.getSignedRange(SE.getSCEV(Next))
          .intersectWith(SE.getUnsignedRange(SE.getSCEV(Next)));
  if (PhiR.isFullSet() || NextR.isFullSet())
    return false;
  for (ICmpInst *Cmp : Cmps) {
    const ConstantRange &R = Cmp->getOperand(0) == &Phi ? PhiR : NextR;
    if (!fits16(R, cast<ConstantInt>(Cmp->getOperand(1))->getValue(),
                Cmp->getPredicate()))
      return false;
  }
  // Truncation is then exact for the start value too (it is a value of the
  // counter).
  LLVM_DEBUG(dbgs() << "Narrowing loop counter " << Phi << "\n");

  Type *I16 = Type::getInt16Ty(Phi.getContext());
  IRBuilder<> B(&Phi);
  PHINode *NPhi = B.CreatePHI(I16, 2, Phi.getName() + ".n16");
  B.SetInsertPoint(Next);
  Value *NNext =
      B.CreateAdd(NPhi, ConstantInt::get(I16, Step->trunc(16)),
                  Next->getName() + ".n16");
  NPhi->addIncoming(ConstantInt::get(I16, Start->getValue().trunc(16)),
                    Preheader);
  NPhi->addIncoming(NNext, Latch);
  for (ICmpInst *Cmp : Cmps) {
    Value *Op = Cmp->getOperand(0) == &Phi ? NPhi : NNext;
    auto *C = cast<ConstantInt>(Cmp->getOperand(1));
    Cmp->setOperand(0, Op);
    Cmp->setOperand(1, ConstantInt::get(I16, C->getValue().trunc(16)));
    Cmp->setSameSign(false);
  }
  Phi.replaceAllUsesWith(PoisonValue::get(Ty));
  Next->replaceAllUsesWith(PoisonValue::get(Ty));
  Next->eraseFromParent();
  Phi.eraseFromParent();
  SE.forgetLoop(&L);
  ++NumNarrowed;
  return true;
}

bool RL78NarrowLoopCounters::runOnFunction(Function &F) {
  if (!EnableNarrowCounters || skipFunction(F))
    return false;
  LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
  ScalarEvolution &SE = getAnalysis<ScalarEvolutionWrapperPass>().getSE();
  bool Changed = false;
  for (Loop *L : LI.getLoopsInPreorder())
    for (PHINode &Phi : llvm::make_early_inc_range(L->getHeader()->phis()))
      Changed |= narrow(Phi, *L, SE);
  return Changed;
}
