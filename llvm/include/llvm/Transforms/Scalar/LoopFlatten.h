//===- LoopFlatten.h - Loop Flatten ----------------  -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file provides the interface for the Loop Flatten Pass.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_SCALAR_LOOPFLATTEN_H
#define LLVM_TRANSFORMS_SCALAR_LOOPFLATTEN_H

#include "llvm/Analysis/LoopAnalysisManager.h"
#include "llvm/IR/PassManager.h"

namespace llvm {
class LPMUpdater;
class LoopNest;

class LoopFlattenPass : public OptionalPassInfoMixin<LoopFlattenPass> {
  // Version a loop nest on the overflow check even when the trip count type
  // is not a legal integer, so that the check is not one instruction.
  bool VersionIllegalTripCount;

public:
  LoopFlattenPass(bool VersionIllegalTripCount = false)
      : VersionIllegalTripCount(VersionIllegalTripCount) {}

  LLVM_ABI PreservedAnalyses run(LoopNest &LN, LoopAnalysisManager &LAM,
                                 LoopStandardAnalysisResults &AR,
                                 LPMUpdater &U);
};

} // end namespace llvm

#endif // LLVM_TRANSFORMS_SCALAR_LOOPFLATTEN_H
