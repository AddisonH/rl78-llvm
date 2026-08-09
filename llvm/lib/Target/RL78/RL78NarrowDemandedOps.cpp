//===- RL78NarrowDemandedOps.cpp - Narrow 32-bit ops to 16 bits -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// RL78 is a 16-bit machine, so every i32 operation costs at least two
// instructions and `mul i32` costs an out-of-line call to __COM_lmul. Very
// often only the low 16 bits of such a value are ever observed -- CoreMark's
// matrix code is the archetype:
//
//   %7  = mul i32 %6, %0
//   %10 = add i32 %9, %7
//   %11 = trunc i32 %10 to i16      ; the only use
//   %12 = getelementptr inbounds i16, ptr %1, i16 %11
//
// InstCombine and AggressiveInstCombine (TruncInstCombine) both decline this:
// the expression DAG rooted at the trunc reaches a loop PHI, and TruncInstCombine
// does not narrow through PHIs. The DemandedBits analysis *does* propagate
// through PHIs and reports 0xffff here, so use it directly.
//
// For and/or/xor/add/sub/mul the low 16 bits of the result depend only on the
// low 16 bits of the operands, so when nothing above bit 15 is demanded the
// operation can be redone in i16. Shifts are deliberately excluded: a shift
// amount >= 16 is well defined in i32 but poison in i16.
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

  // This tree no longer ships DemandedBitsWrapperPass, so construct the
  // analysis directly from the two legacy wrappers it needs.
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

// The low half of the result depends only on the low halves of the operands.
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
      // Nothing above bit 15 may be observed by any user.
      if (DB.getDemandedBits(BO).getActiveBits() > 16)
        continue;
      Worklist.push_back(BO);
    }

  for (BinaryOperator *BO : Worklist) {
    IRBuilder<> B(BO);
    Value *L = B.CreateTrunc(BO->getOperand(0), I16);
    Value *R = B.CreateTrunc(BO->getOperand(1), I16);
    // Narrowing invalidates nuw/nsw: a value that could not overflow in 32
    // bits may well overflow in 16. Create the new operator without flags.
    Value *Narrow = B.CreateBinOp(BO->getOpcode(), L, R);
    Value *Wide = B.CreateZExt(Narrow, BO->getType());
    LLVM_DEBUG(dbgs() << "RL78 narrowing: " << *BO << " -> " << *Narrow << '\n');
    BO->replaceAllUsesWith(Wide);
    BO->eraseFromParent();
  }

  if (Worklist.empty())
    return false;

  // Fold trunc(zext(x)) back to x. Narrowing a chain of operations leaves one
  // of these at every joint, and the original consumer was already a trunc, so
  // this collapses the whole chain to i16. Done here rather than by running a
  // general InstCombine, which perturbs codegen target-wide.
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
