//===------ RL78GenSet1Clr1Intrin.h - IR-level matcher for clr1/set1 ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
//
//===----------------------------------------------------------------------===//

#include "llvm/IR/Function.h"
#include "llvm/IR/PassManager.h"

namespace llvm {

struct RL78GenSet1Clr1IntrinPass
    : public llvm::PassInfoMixin<RL78GenSet1Clr1IntrinPass> {
  llvm::PreservedAnalyses run(llvm::Function &F,
                              llvm::FunctionAnalysisManager &AM);
  static bool isRequired() { return true; }
};

}
