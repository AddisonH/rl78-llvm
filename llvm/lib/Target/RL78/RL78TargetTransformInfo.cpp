//===-- RL78TargetTransformInfo.cpp - RL78 specific TTI pass ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
/// \file
/// This file implements a TargetTransformInfo analysis pass specific to the
/// RL78 target machine. It uses the target's detailed information to provide
/// more precise answers to certain TTI queries, while letting the target
/// independent and default TTI implementations handle the rest.
///

#include "RL78TargetTransformInfo.h"
#include "llvm/Analysis/InlineCost.h"
#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/CodeGen/BasicTTIImpl.h"
#include "llvm/CodeGen/CostTable.h"
#include "llvm/CodeGen/TargetLowering.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/PatternMatch.h"
#include "llvm/Support/Debug.h"

using namespace llvm;

#define DEBUG_TYPE "RL78tti"

TTI::MemCmpExpansionOptions
RL78TTIImpl::enableMemCmpExpansion(bool OptSize, bool IsZeroCmp) const {
  TTI::MemCmpExpansionOptions Options;
  Options.LoadSizes = { 2, 1 };
  Options.MaxNumLoads = TLI->getMaxExpandSizeMemcmp(OptSize);
  return Options;
}

bool RL78TTIImpl::hasDivRemOp(Type *DataType, bool IsSigned) const {
  EVT VT = TLI->getValueType(DL, DataType);
  return !IsSigned && ST->isRL78S3CoreType() &&
         (VT == MVT::i16 || VT == MVT::i32);
}

// Whether the loop has an i32 reduction of 16x16-bit products, which ISel
// turns into MACH_cg/MACHU_cg accumulating in MACR.
static bool hasMACReduction(const Loop *L) {
  using namespace PatternMatch;
  for (const PHINode &Phi : L->getHeader()->phis()) {
    if (!Phi.getType()->isIntegerTy(32))
      continue;
    auto *Next = dyn_cast<Instruction>(Phi.getIncomingValueForBlock(
        L->getLoopLatch() ? L->getLoopLatch() : L->getHeader()));
    Value *A, *B;
    if (Next && L->contains(Next) &&
        match(Next, m_c_Add(m_Specific(&Phi),
                            m_Mul(m_ZExtOrSExt(m_Value(A)),
                                  m_ZExtOrSExt(m_Value(B))))) &&
        A->getType()->getScalarSizeInBits() <= 16 &&
        B->getType()->getScalarSizeInBits() <= 16)
      return true;
  }
  return false;
}

static bool isAggressive(const RL78TargetLowering *TLI) {
  return TLI->getTargetMachine().getOptLevel() == CodeGenOptLevel::Aggressive;
}

int RL78TTIImpl::adjustInliningThreshold(const CallBase *CB) const {
  const Function *Caller = CB->getCaller();
  // A call is three or four bytes and its arguments arrive in registers:
  // when optimizing for size, inline only a callee about as small as the
  // call (the minsize threshold), or one with no other caller.
  if (Caller->hasOptSize())
    return Caller->hasMinSize() ? 0
                                : InlineConstants::OptMinSizeThreshold -
                                      InlineConstants::OptSizeThreshold;
  // A call and return with the register saves around them cost tens of
  // clocks: at -O3 inline up to a threshold of 600.
  if (isAggressive(TLI))
    return 600 - InlineConstants::OptAggressiveThreshold;
  return 0;
}

void RL78TTIImpl::getUnrollingPreferences(
    Loop *L, ScalarEvolution &SE, TTI::UnrollingPreferences &UP,
    OptimizationRemarkEmitter *ORE) const {
  BaseT::getUnrollingPreferences(L, SE, UP, ORE);
  // At -O3, unroll loops whose trip count is known only at run time
  // (CoreMark's list and matrix loops: 15% of its clocks).
  if (isAggressive(TLI))
    UP.Runtime = true;

  // Unroll-and-jam runs at -O3 (RL78TargetMachine adds the pass). It pays on
  // RL78 except around MACH_cg: there is one MACR, and jamming an outer loop
  // gives the inner reduction one accumulator per copy, each swapped through
  // MACR around every MACH_cg. Plain unrolling of the inner loop keeps the
  // single accumulator in MACR.
  UP.UnrollAndJam = true;
  if (ST->isRL78S3CoreType() && L->getSubLoops().size() == 1 &&
      hasMACReduction(L->getSubLoops()[0]))
    UP.UnrollAndJam = false;

  // When optimizing for size: a body of a few instructions that runs a
  // known, small number of times is smaller without its counter and branch.
  UP.OptSizeThreshold = 9;

  // A small innermost loop spends a good part of its time on the counter and
  // the branch. At -O3 those with a count known only at run time are
  // unrolled (above); do the same for a constant count too large to unroll
  // completely, and for a count with a known bound.
  if (!L->isInnermost() || L->getHeader()->getParent()->hasOptSize())
    return;
  unsigned Size = 0;
  for (const BasicBlock *BB : L->blocks())
    for (const Instruction &I : *BB) {
      if (isa<CallBase>(I) && !isa<IntrinsicInst>(I))
        return;
      ++Size;
    }
  if (Size > 30)
    return;
  UP.Partial = UP.UpperBound = true;
  UP.PartialThreshold = 150;
  // As many copies as runtime unrolling makes; more save little more.
  UP.MaxCount = 8;
}
