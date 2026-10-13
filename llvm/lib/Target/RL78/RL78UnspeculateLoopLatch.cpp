//===- RL78UnspeculateLoopLatch.cpp - Test before the first iteration ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Loop rotation folds a latch that is one cheap instruction into the header
// instead of rotating (simplifyLoopLatch), so
//
//     while (x < t) x += p;
//
// arrives as one block that computes the next value before it knows whether
// there is a next iteration:
//
//     loop: x = phi [x0, entry], [x.next, loop]
//           c = icmp slt x, t
//           x.next = add x, p
//           br c, loop, exit                ; exit uses x
//
// That is one add too many each time the loop is entered, and both x and
// x.next are live at the branch; LSR then starts from x0 - p to have one
// value, a subtraction more. With 32-bit values these are several
// instructions each and four registers of the four there are. Test before
// the first iteration instead:
//
//     entry: c0 = icmp slt x0, t
//            br c0, loop, exit
//     loop:  x = phi [x0, entry], [x.next, loop]
//            x.next = add x, p
//            c = icmp slt x.next, t
//            br c, loop, exit               ; exit uses phi [x0], [x.next]
//
// This is done where a value the loop computes is wider than 16 bits; for
// narrower ones the second comparison costs what the addition did.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-unspeculate-loop-latch"

STATISTIC(NumLoops, "Number of loops that test before the first iteration");

static cl::opt<bool>
    EnableUnspeculate("rl78-unspeculate-latch", cl::Hidden, cl::init(true),
                      cl::desc("Test before the first iteration where a "
                               "loop computes its next values before its "
                               "exit test"));

namespace {

class RL78UnspeculateLoopLatch : public FunctionPass {
public:
  static char ID;
  RL78UnspeculateLoopLatch() : FunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 unspeculate loop latch";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    // Not LoopSimplify: with LSR off nothing else asks for it, and the
    // blocks it adds cost bytes. A loop without a preheader is left alone.
    AU.addRequired<LoopInfoWrapperPass>();
    AU.addPreserved<LoopInfoWrapperPass>();
  }

  bool runOnFunction(Function &F) override;

private:
  bool convert(Loop &L);
};

} // end anonymous namespace

char RL78UnspeculateLoopLatch::ID = 0;

INITIALIZE_PASS_BEGIN(RL78UnspeculateLoopLatch, DEBUG_TYPE,
                      "RL78 unspeculate loop latch", false, false)
INITIALIZE_PASS_DEPENDENCY(LoopInfoWrapperPass)
INITIALIZE_PASS_END(RL78UnspeculateLoopLatch, DEBUG_TYPE,
                    "RL78 unspeculate loop latch", false, false)

FunctionPass *llvm::createRL78UnspeculateLoopLatchPass() {
  return new RL78UnspeculateLoopLatch();
}

bool RL78UnspeculateLoopLatch::convert(Loop &L) {
  BasicBlock *H = L.getHeader();
  BasicBlock *Pre = L.getLoopPreheader();
  if (L.getNumBlocks() != 1 || !Pre)
    return false;
  auto *Br = dyn_cast<BranchInst>(H->getTerminator());
  if (!Br || !Br->isConditional())
    return false;
  auto *Cmp = dyn_cast<ICmpInst>(Br->getCondition());
  if (!Cmp || Cmp->getParent() != H || !Cmp->hasOneUse())
    return false;
  unsigned ExitIdx = Br->getSuccessor(0) == H ? 1 : 0;
  BasicBlock *Exit = Br->getSuccessor(ExitIdx);
  // The values that leave the loop meet the ones of the new edge in the
  // exit block, so nothing else may come in there.
  if (Exit == H || Exit->getSinglePredecessor() != H)
    return false;

  // What the block computes besides the test has to be for the next
  // iteration only: used by the phis, or by what the phis use. The test
  // reads the phis, that is the values of this iteration.
  bool Wide = false;
  for (Instruction &I : *H) {
    if (isa<PHINode>(I) || &I == Cmp || &I == Br || I.isDebugOrPseudoInst())
      continue;
    if (!isa<BinaryOperator>(I) && !isa<CastInst>(I) &&
        !isa<GetElementPtrInst>(I))
      return false;
    if (I.getType()->isIntegerTy() && I.getType()->getIntegerBitWidth() > 16)
      Wide = true;
    for (const User *U : I.users()) {
      const auto *UI = cast<Instruction>(U);
      if (UI->getParent() != H || UI == Cmp)
        return false;
    }
  }
  if (!Wide)
    return false;
  for (const Value *Op : Cmp->operands())
    if (const auto *OpI = dyn_cast<Instruction>(Op);
        OpI && OpI->getParent() == H && !isa<PHINode>(OpI))
      return false;

  LLVM_DEBUG(dbgs() << "Testing before the first iteration of loop "
                    << H->getName() << " in " << H->getParent()->getName()
                    << "\n");

  // A phi of the exit block has one incoming value: use that.
  while (auto *Phi = dyn_cast<PHINode>(&Exit->front())) {
    Phi->replaceAllUsesWith(Phi->getIncomingValue(0));
    Phi->eraseFromParent();
  }

  // The test of the values the loop is entered with.
  auto *PreBr = cast<BranchInst>(Pre->getTerminator());
  auto *Cmp0 = cast<ICmpInst>(Cmp->clone());
  Cmp0->insertBefore(PreBr->getIterator());
  for (Use &U : Cmp0->operands())
    if (auto *Phi = dyn_cast<PHINode>(U.get()); Phi && Phi->getParent() == H)
      U.set(Phi->getIncomingValueForBlock(Pre));
  BranchInst *NewBr = ExitIdx == 1 ? BranchInst::Create(H, Exit, Cmp0)
                                   : BranchInst::Create(Exit, H, Cmp0);
  NewBr->insertBefore(PreBr->getIterator());
  NewBr->setDebugLoc(PreBr->getDebugLoc());
  PreBr->eraseFromParent();

  // The values that leave: from the new edge what the loop is entered with,
  // from the loop what the next iteration would have had.
  for (PHINode &Phi : H->phis()) {
    SmallVector<Use *, 4> Outside;
    for (Use &U : Phi.uses())
      if (cast<Instruction>(U.getUser())->getParent() != H)
        Outside.push_back(&U);
    if (Outside.empty())
      continue;
    PHINode *Out = PHINode::Create(Phi.getType(), 2, Phi.getName() + ".out",
                                   Exit->begin());
    Out->addIncoming(Phi.getIncomingValueForBlock(Pre), Pre);
    Out->addIncoming(Phi.getIncomingValueForBlock(H), H);
    for (Use *U : Outside)
      U->set(Out);
  }

  // The test of the next iteration's values, after they are computed.
  Cmp->moveBefore(Br->getIterator());
  for (Use &U : Cmp->operands())
    if (auto *Phi = dyn_cast<PHINode>(U.get()); Phi && Phi->getParent() == H)
      U.set(Phi->getIncomingValueForBlock(H));
  ++NumLoops;
  return true;
}

bool RL78UnspeculateLoopLatch::runOnFunction(Function &F) {
  if (!EnableUnspeculate || skipFunction(F))
    return false;
  LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
  bool Changed = false;
  for (Loop *L : LI.getLoopsInPreorder())
    Changed |= convert(*L);
  return Changed;
}
