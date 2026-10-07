//===-- RL78ExpandInlineAsm.cpp - inline asm to RL78 intrinsics -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Replaces single-instruction inline asm such as asm("nop") or asm("ei") with
// the matching RL78 intrinsic, so that the DAG combines keyed on those
// intrinsics see them. LLVM 17's CodeGenPrepare did this through the (since
// removed) TargetLowering::ExpandInlineAsm hook.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78ISelLowering.h"
#include "RL78Subtarget.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/Instructions.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Target/TargetMachine.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-expand-inline-asm"

namespace {
class RL78ExpandInlineAsm : public FunctionPass {
public:
  static char ID;
  RL78ExpandInlineAsm() : FunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 expand inline asm to intrinsics";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<TargetPassConfig>();
    AU.setPreservesCFG();
  }

  bool runOnFunction(Function &F) override;
};
} // end anonymous namespace

char RL78ExpandInlineAsm::ID = 0;

INITIALIZE_PASS_BEGIN(RL78ExpandInlineAsm, DEBUG_TYPE,
                      "RL78 expand inline asm to intrinsics", false, false)
INITIALIZE_PASS_DEPENDENCY(TargetPassConfig)
INITIALIZE_PASS_END(RL78ExpandInlineAsm, DEBUG_TYPE,
                    "RL78 expand inline asm to intrinsics", false, false)

bool RL78ExpandInlineAsm::runOnFunction(Function &F) {
  if (skipFunction(F))
    return false;
  const TargetMachine &TM =
      getAnalysis<TargetPassConfig>().getTM<TargetMachine>();
  const auto *TLI = static_cast<const RL78TargetLowering *>(
      TM.getSubtargetImpl(F)->getTargetLowering());

  SmallVector<CallInst *, 4> Candidates;
  for (BasicBlock &BB : F)
    for (Instruction &I : BB)
      if (auto *CI = dyn_cast<CallInst>(&I))
        if (CI->isInlineAsm() && CI->arg_empty())
          Candidates.push_back(CI);

  bool Changed = false;
  for (CallInst *CI : Candidates)
    Changed |= TLI->ExpandInlineAsm(CI);
  return Changed;
}

FunctionPass *llvm::createRL78ExpandInlineAsmPass() {
  return new RL78ExpandInlineAsm();
}
