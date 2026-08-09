//===- RL78NarrowDemandedOps.cpp - Narrow 32-bit ops to 16 bits -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Redo an i32 operation in i16 when DemandedBits shows nothing above bit 15 is
// used. i32 costs two registers here and mul i32 costs a call to __COM_lmul,
// so this turns CoreMark's index arithmetic into a single MULHU.
// TruncInstCombine cannot do it: it does not narrow through the loop PHI.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "llvm/Analysis/AssumptionCache.h"
#include "llvm/Analysis/DemandedBits.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/Transforms/Utils/Local.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-narrow-demanded"

static cl::opt<bool> EnableNarrowing(
    "rl78-narrow-demanded-ops", cl::Hidden, cl::init(true),
    cl::desc("Redo 32-bit operations in 16 bits when only the low half is "
             "demanded"));

namespace {
class RL78NarrowDemandedOps : public FunctionPass {
public:
  static char ID;
  RL78NarrowDemandedOps() : FunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 narrow demanded 32-bit operations";
  }

  // DemandedBitsWrapperPass is gone, so DemandedBits is built by hand below.
  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<AssumptionCacheTracker>();
    AU.addRequired<DominatorTreeWrapperPass>();
    AU.setPreservesCFG();
  }

  bool runOnFunction(Function &F) override;
};
} // end anonymous namespace

char RL78NarrowDemandedOps::ID = 0;

INITIALIZE_PASS_BEGIN(RL78NarrowDemandedOps, DEBUG_TYPE,
                      "RL78 narrow demanded 32-bit operations", false, false)
INITIALIZE_PASS_DEPENDENCY(AssumptionCacheTracker)
INITIALIZE_PASS_DEPENDENCY(DominatorTreeWrapperPass)
INITIALIZE_PASS_END(RL78NarrowDemandedOps, DEBUG_TYPE,
                    "RL78 narrow demanded 32-bit operations", false, false)

FunctionPass *llvm::createRL78NarrowDemandedOpsPass() {
  return new RL78NarrowDemandedOps();
}

// Ops whose low half depends only on the low halves of the operands. Shifts are
// excluded: a shift amount >= 16 is defined in i32 but poison in i16.
static bool isNarrowableOpcode(unsigned Opc) {
  switch (Opc) {
  case Instruction::Mul:
  case Instruction::Add:
  case Instruction::Sub:
  case Instruction::And:
  case Instruction::Or:
  case Instruction::Xor:
    return true;
  default:
    return false;
  }
}

bool RL78NarrowDemandedOps::runOnFunction(Function &F) {
  if (!EnableNarrowing || F.empty())
    return false;

  AssumptionCache &AC = getAnalysis<AssumptionCacheTracker>().getAssumptionCache(F);
  DominatorTree &DT = getAnalysis<DominatorTreeWrapperPass>().getDomTree();
  DemandedBits DB(F, AC, DT);
  LLVMContext &Ctx = F.getContext();
  Type *I16 = Type::getInt16Ty(Ctx);

  SmallVector<BinaryOperator *, 8> Worklist;
  for (BasicBlock &BB : F)
    for (Instruction &I : BB) {
      auto *BO = dyn_cast<BinaryOperator>(&I);
      if (!BO || !BO->getType()->isIntegerTy(32) ||
          !isNarrowableOpcode(BO->getOpcode()))
        continue;
      if (DB.getDemandedBits(BO).getActiveBits() > 16)
        continue;
      Worklist.push_back(BO);
    }

  for (BinaryOperator *BO : Worklist) {
    IRBuilder<> B(BO);
    Value *L = B.CreateTrunc(BO->getOperand(0), I16);
    Value *R = B.CreateTrunc(BO->getOperand(1), I16);
    // No nuw/nsw: what cannot overflow in 32 bits may overflow in 16.
    Value *Narrow = B.CreateBinOp(BO->getOpcode(), L, R);
    Value *Wide = B.CreateZExt(Narrow, BO->getType());
    LLVM_DEBUG(dbgs() << "RL78 narrowing: " << *BO << " -> " << *Narrow << '\n');
    BO->replaceAllUsesWith(Wide);
    BO->eraseFromParent();
  }

  if (Worklist.empty())
    return false;

  // Fold trunc(zext(x)) left at each joint, collapsing the chain to i16. Done
  // here because running InstCombine in addIRPasses perturbs codegen target
  // wide.
  SmallVector<Instruction *, 16> Folded;
  for (BasicBlock &BB : F)
    for (Instruction &I : BB) {
      auto *T = dyn_cast<TruncInst>(&I);
      if (!T || !T->getType()->isIntegerTy(16))
        continue;
      auto *Z = dyn_cast<ZExtInst>(T->getOperand(0));
      if (!Z || !Z->getSrcTy()->isIntegerTy(16))
        continue;
      T->replaceAllUsesWith(Z->getOperand(0));
      Folded.push_back(T);
    }
  for (Instruction *I : Folded)
    if (I->use_empty())
      I->eraseFromParent();

  // Drop whatever that left behind.
  bool Changed = true;
  while (Changed) {
    Changed = false;
    for (BasicBlock &BB : F)
      for (Instruction &I : make_early_inc_range(BB))
        if (isInstructionTriviallyDead(&I)) {
          I.eraseFromParent();
          Changed = true;
        }
  }

  return true;
}
