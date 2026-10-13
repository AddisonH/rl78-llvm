//===- RL78OuterLoopPointers.cpp - Step pointers in outer loops ----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Loop strength reduction leaves a loop that has a loop inside it alone, so
// an element of an array indexed by the counter of such a loop has its
// address computed in every iteration:
//
//     movw ax, bc; shlw ax, 2; addw ax, #_array; movw hl, ax
//
// and from a frame address the base is two more instructions. Step a pointer
// instead where the address is the base plus a constant times the counter:
// that is one ADDW or a few INCW an iteration, and a pointer in a stack slot
// is as cheap to step as the counter was.
//
// The accesses of a loop whose addresses differ by a constant that fits
// [HL+byte] share one pointer. At most two pointers are made for a loop, the
// ones with the most accesses: every one is a value live through the loops
// inside.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/Transforms/Utils/Local.h"
#include "llvm/Transforms/Utils/ScalarEvolutionExpander.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-outer-loop-pointers"

STATISTIC(NumPointers, "Number of pointers stepped in outer loops");

static cl::opt<bool>
    EnableOuterLoopPointers("rl78-step-outer-pointers", cl::Hidden,
                            cl::init(true),
                            cl::desc("Step pointers for the array accesses "
                                     "of loops that contain loops"));

static cl::opt<unsigned>
    MaxPointers("rl78-outer-loop-max-pointers", cl::Hidden, cl::init(2),
                cl::desc("The most pointers stepped in one outer loop"));

namespace {

class RL78OuterLoopPointers : public FunctionPass {
public:
  static char ID;
  RL78OuterLoopPointers() : FunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 outer loop pointers";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    // Not LoopSimplify, which costs bytes where nothing else asks for it:
    // the pass runs after LSR, which leaves the loops in that form.
    AU.addRequired<LoopInfoWrapperPass>();
    AU.addRequired<ScalarEvolutionWrapperPass>();
    AU.addPreserved<LoopInfoWrapperPass>();
    AU.setPreservesCFG();
  }

  bool runOnFunction(Function &F) override;

private:
  bool convert(Loop &L, LoopInfo &LI, ScalarEvolution &SE);
};

// An access and how far its address is from the address its group starts
// with.
struct Access {
  Instruction *I;
  unsigned PtrIdx;
  int64_t Offset;
};

// The accesses that one pointer serves: their addresses are
// {Start + Offset,+,Step} in the loop.
struct Group {
  const SCEV *Start;
  const SCEVConstant *Step;
  SmallVector<Access, 4> Accesses;
};

} // end anonymous namespace

char RL78OuterLoopPointers::ID = 0;

INITIALIZE_PASS_BEGIN(RL78OuterLoopPointers, DEBUG_TYPE,
                      "RL78 outer loop pointers", false, false)
INITIALIZE_PASS_DEPENDENCY(LoopInfoWrapperPass)
INITIALIZE_PASS_DEPENDENCY(ScalarEvolutionWrapperPass)
INITIALIZE_PASS_END(RL78OuterLoopPointers, DEBUG_TYPE,
                    "RL78 outer loop pointers", false, false)

FunctionPass *llvm::createRL78OuterLoopPointersPass() {
  return new RL78OuterLoopPointers();
}

bool RL78OuterLoopPointers::convert(Loop &L, LoopInfo &LI,
                                    ScalarEvolution &SE) {
  BasicBlock *Preheader = L.getLoopPreheader();
  BasicBlock *Header = L.getHeader();
  BasicBlock *Latch = L.getLoopLatch();
  if (!Preheader || !Latch)
    return false;

  SCEVExpander Expander(SE, "outerptr");
  SmallVector<Group, 4> Groups;
  for (BasicBlock *BB : L.blocks()) {
    // In a loop inside this one the address does not change: it is computed
    // once before that loop as it is.
    if (LI.getLoopFor(BB) != &L)
      continue;
    for (Instruction &I : *BB) {
      unsigned PtrIdx;
      if (isa<LoadInst>(I))
        PtrIdx = LoadInst::getPointerOperandIndex();
      else if (isa<StoreInst>(I))
        PtrIdx = StoreInst::getPointerOperandIndex();
      else
        continue;
      Value *Ptr = I.getOperand(PtrIdx);
      // An address that is computed in the loop: one that is a phi already
      // is stepped.
      if (!isa<GetElementPtrInst>(Ptr) ||
          !L.contains(cast<Instruction>(Ptr)))
        continue;
      const auto *AR = dyn_cast<SCEVAddRecExpr>(SE.getSCEV(Ptr));
      if (!AR || AR->getLoop() != &L || !AR->isAffine())
        continue;
      const auto *Step = dyn_cast<SCEVConstant>(AR->getStepRecurrence(SE));
      const SCEV *Start = AR->getStart();
      if (!Step || Step->isZero() || !Step->getAPInt().isSignedIntN(8) ||
          !SE.isLoopInvariant(Start, &L) ||
          !Expander.isSafeToExpandAt(Start, Preheader->getTerminator()))
        continue;

      bool Found = false;
      for (Group &G : Groups) {
        if (G.Step != Step)
          continue;
        const auto *Diff =
            dyn_cast<SCEVConstant>(SE.getMinusSCEV(Start, G.Start));
        if (!Diff || !Diff->getAPInt().isSignedIntN(16))
          continue;
        G.Accesses.push_back({&I, PtrIdx, Diff->getAPInt().getSExtValue()});
        Found = true;
        break;
      }
      if (!Found)
        Groups.push_back({Start, Step, {{&I, PtrIdx, 0}}});
    }
  }
  if (Groups.empty())
    return false;

  // The group starts at its lowest address, and holds what [HL+byte] reaches
  // from there.
  for (Group &G : Groups) {
    int64_t Min = G.Accesses[0].Offset;
    for (const Access &A : G.Accesses)
      Min = std::min(Min, A.Offset);
    erase_if(G.Accesses,
             [&](const Access &A) { return A.Offset - Min > 255; });
    for (Access &A : G.Accesses)
      A.Offset -= Min;
    if (Min)
      G.Start = SE.getAddExpr(
          G.Start,
          SE.getConstant(SE.getEffectiveSCEVType(G.Start->getType()), Min,
                         true));
  }
  llvm::stable_sort(Groups, [](const Group &A, const Group &B) {
    return A.Accesses.size() > B.Accesses.size();
  });
  if (Groups.size() > MaxPointers)
    Groups.resize(MaxPointers);

  const DataLayout &DL = Header->getDataLayout();
  LLVMContext &Ctx = Header->getContext();
  Type *I8 = Type::getInt8Ty(Ctx);
  for (Group &G : Groups) {
    Type *PtrTy = G.Accesses[0].I->getOperand(G.Accesses[0].PtrIdx)->getType();
    Type *IdxTy = DL.getIndexType(PtrTy);
    LLVM_DEBUG(dbgs() << "Stepping a pointer in loop " << Header->getName()
                      << " from " << *G.Start << " by " << *G.Step << " for "
                      << G.Accesses.size() << " accesses\n");
    Value *Start =
        Expander.expandCodeFor(G.Start, PtrTy, Preheader->getTerminator());
    PHINode *Phi = PHINode::Create(PtrTy, 2, "outerptr", Header->begin());
    IRBuilder<> B(Latch->getTerminator());
    Value *Next = B.CreateGEP(
        I8, Phi,
        ConstantInt::get(IdxTy, G.Step->getAPInt().getSExtValue(), true),
        "outerptr.next");
    for (BasicBlock *Pred : predecessors(Header))
      Phi->addIncoming(Pred == Latch ? Next : Start, Pred);
    for (const Access &A : G.Accesses) {
      Value *Old = A.I->getOperand(A.PtrIdx);
      Value *New = Phi;
      if (A.Offset) {
        B.SetInsertPoint(A.I);
        New = B.CreateGEP(I8, Phi, ConstantInt::get(IdxTy, A.Offset));
      }
      A.I->setOperand(A.PtrIdx, New);
      RecursivelyDeleteTriviallyDeadInstructions(Old);
    }
    ++NumPointers;
  }
  SE.forgetLoop(&L);
  return true;
}

bool RL78OuterLoopPointers::runOnFunction(Function &F) {
  // A pointer more to step is a few bytes more.
  if (!EnableOuterLoopPointers || skipFunction(F) || F.hasOptSize())
    return false;
  LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();
  ScalarEvolution &SE = getAnalysis<ScalarEvolutionWrapperPass>().getSE();
  bool Changed = false;
  for (Loop *L : LI.getLoopsInPreorder())
    if (!L->isInnermost())
      Changed |= convert(*L, LI, SE);
  return Changed;
}
