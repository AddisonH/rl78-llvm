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
  // Not sure if this expansion ever pays off when opt for size and -mfar-data...
  
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
// turns into MACH/MACHU accumulating in MACR.
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

void RL78TTIImpl::getUnrollingPreferences(
    Loop *L, ScalarEvolution &SE, TTI::UnrollingPreferences &UP,
    OptimizationRemarkEmitter *ORE) const {
  BaseT::getUnrollingPreferences(L, SE, UP, ORE);
  // Unroll-and-jam runs only when the driver enables it (-O3). It pays on
  // RL78 except around MACH: there is one MACR, and jamming an outer loop
  // gives the inner reduction one accumulator per copy, each swapped through
  // MACR around every MACH. Plain unrolling of the inner loop keeps the
  // single accumulator in MACR.
  UP.UnrollAndJam = true;
  if (ST->isRL78S3CoreType() && L->getSubLoops().size() == 1 &&
      hasMACReduction(L->getSubLoops()[0]))
    UP.UnrollAndJam = false;
}
