//===- RL78BiasSignedCompares.cpp - Signed compares with a loop invariant -===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// There is no signed conditional branch. A signed comparison is the unsigned
// one with the carry corrected by the sign bits of both operands:
//
//     cmpw  ax, bc
//     xor1  cy, a.7
//     mov   a, b
//     xor1  cy, a.7
//
// The same order results from comparing the operands with their sign bits
// inverted, which is one instruction for the operand in AX:
//
//     xor   a, #0x80
//     cmpw  ax, bc              ; BC holds the other operand ^ 0x8000
//
// That is no gain when the other operand has to be inverted next to the
// comparison as well, and none against a constant, whose sign is known. It
// is one where the other operand does not change in a loop: this pass inverts
// its sign bit once, before the outermost loop it is invariant in, and makes
// the comparisons in the loop unsigned ones.
//
// The optimizer writes such comparisons as signed ones (InstCombine), so
// this runs with the passes that prepare for selection, after LSR.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-bias-signed-compares"

STATISTIC(NumCompares, "Number of signed comparisons made unsigned");
STATISTIC(NumInvariants, "Number of loop invariants with inverted sign bit");

static cl::opt<bool>
    EnableBias("rl78-bias-compares", cl::Hidden, cl::init(true),
               cl::desc("Compare with a loop invariant whose sign bit is "
                        "inverted before the loop instead of signed"));

namespace {

class RL78BiasSignedCompares : public FunctionPass {
public:
  static char ID;
  RL78BiasSignedCompares() : FunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 bias signed compares";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    // Not LoopSimplify: a loop without a preheader is left alone.
    AU.addRequired<LoopInfoWrapperPass>();
    AU.addPreserved<LoopInfoWrapperPass>();
    AU.setPreservesCFG();
  }

  bool runOnFunction(Function &F) override;
};

} // end anonymous namespace

char RL78BiasSignedCompares::ID = 0;

INITIALIZE_PASS_BEGIN(RL78BiasSignedCompares, DEBUG_TYPE,
                      "RL78 bias signed compares", false, false)
INITIALIZE_PASS_DEPENDENCY(LoopInfoWrapperPass)
INITIALIZE_PASS_END(RL78BiasSignedCompares, DEBUG_TYPE,
                    "RL78 bias signed compares", false, false)

FunctionPass *llvm::createRL78BiasSignedComparesPass() {
  return new RL78BiasSignedCompares();
}

bool RL78BiasSignedCompares::runOnFunction(Function &F) {
  // The inversion before the loop is as long as what one comparison saves.
  if (!EnableBias || skipFunction(F) || F.hasOptSize())
    return false;
  LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
  if (LI.empty())
    return false;

  SmallVector<ICmpInst *, 8> Compares;
  for (BasicBlock &BB : F)
    if (LI.getLoopFor(&BB))
      for (Instruction &I : BB)
        if (auto *Cmp = dyn_cast<ICmpInst>(&I);
            Cmp && Cmp->isSigned() && Cmp->getOperand(0)->getType()->isIntegerTy())
          Compares.push_back(Cmp);

  // The inverted value of an invariant, by the block it is computed in.
  DenseMap<std::pair<Value *, BasicBlock *>, Value *> Inverted;
  bool Changed = false;
  for (ICmpInst *Cmp : Compares) {
    Loop *L = LI.getLoopFor(Cmp->getParent());
    unsigned InvIdx;
    if (L->isLoopInvariant(Cmp->getOperand(0)) ==
        L->isLoopInvariant(Cmp->getOperand(1)))
      continue;
    InvIdx = L->isLoopInvariant(Cmp->getOperand(1));
    Value *Inv = Cmp->getOperand(InvIdx);
    if (isa<Constant>(Inv))
      continue;
    // Inverting the sign bit of X + C is adding C + 0x80...0 to X, and that
    // is what selection makes of it: an addition wider than the one of C.
    Value *Var = Cmp->getOperand(1 - InvIdx);
    if (auto *BO = dyn_cast<BinaryOperator>(Var);
        BO &&
        (BO->getOpcode() == Instruction::Add ||
         BO->getOpcode() == Instruction::Sub) &&
        (isa<ConstantInt>(BO->getOperand(0)) ||
         isa<ConstantInt>(BO->getOperand(1))))
      continue;

    // Before the outermost loop the value is invariant in that has a
    // preheader.
    BasicBlock *Pre = nullptr;
    for (Loop *Out = L; Out && Out->isLoopInvariant(Inv);
         Out = Out->getParentLoop())
      if (BasicBlock *P = Out->getLoopPreheader())
        Pre = P;
    if (!Pre)
      continue;

    APInt Sign = APInt::getSignMask(Inv->getType()->getIntegerBitWidth());
    Value *&InvB = Inverted[{Inv, Pre}];
    if (!InvB) {
      IRBuilder<> B(Pre->getTerminator());
      InvB = B.CreateXor(Inv, Sign, Inv->getName() + ".bias");
      ++NumInvariants;
    }
    IRBuilder<> B(Cmp);
    Cmp->setOperand(1 - InvIdx, B.CreateXor(Var, Sign, Var->getName() + ".bias"));
    Cmp->setOperand(InvIdx, InvB);
    Cmp->setPredicate(Cmp->getUnsignedPredicate());
    ++NumCompares;
    Changed = true;
  }
  return Changed;
}
