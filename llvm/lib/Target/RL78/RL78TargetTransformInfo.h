//===-- RL78TargetTransformInfo.h - RL78 specific TTI -------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception.
//
//===----------------------------------------------------------------------===//
/// \file
/// This file a TargetTransformInfo::Concept conforming object specific to the
/// RL78 target machine. It uses the target's detailed information to
/// provide more precise answers to certain TTI queries, while letting the
/// target independent and default TTI implementations handle the rest.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RL78TARGETTRANSFORMINFO_H
#define LLVM_LIB_TARGET_RL78TARGETTRANSFORMINFO_H

#include "RL78.h"
#include "RL78TargetMachine.h"
#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/CodeGen/BasicTTIImpl.h"
#include "llvm/CodeGen/TargetLowering.h"

namespace llvm {

class RL78TTIImpl : public BasicTTIImplBase<RL78TTIImpl> {
  typedef BasicTTIImplBase<RL78TTIImpl> BaseT;
  typedef TargetTransformInfo TTI;
  friend BaseT;

  const RL78Subtarget *ST;
  const RL78TargetLowering *TLI;
  bool OptSize;

  const RL78Subtarget *getST() const { return ST; }
  const RL78TargetLowering *getTLI() const { return TLI; }

public:
  explicit RL78TTIImpl(const RL78TargetMachine *TM, const Function &F)
      : BaseT(TM, F.getDataLayout()), ST(TM->getSubtargetImpl(F)),
        TLI(ST->getTargetLowering()), OptSize(F.hasOptSize()) {}

  TTI::MemCmpExpansionOptions
  enableMemCmpExpansion(bool OptSize, bool IsZeroCmp) const override;

  bool hasDivRemOp(Type *DataType, bool IsSigned) const override;

  // 32-bit loop counters are common in C (uint32_t, long), and their
  // truncated uses index 16-bit address arithmetic: have LSR
  // strength-reduce those uses.
  bool shouldTrackIllegalIVWidth(unsigned BitWidth) const override {
    return BitWidth == 32;
  }

  // An address is one register, with a small constant at most. Where loop
  // strength reduction saves an induction variable by indexing two bases
  // with one counter, every access pays with an addition: count
  // instructions first.
  bool isLSRCostLess(const TargetTransformInfo::LSRCost &C1,
                     const TargetTransformInfo::LSRCost &C2) const override {
    return std::tie(C1.Insns, C1.NumRegs, C1.AddRecCost, C1.NumIVMuls,
                    C1.NumBaseAdds, C1.ScaleCost, C1.ImmCost, C1.SetupCost) <
           std::tie(C2.Insns, C2.NumRegs, C2.AddRecCost, C2.NumIVMuls,
                    C2.NumBaseAdds, C2.ScaleCost, C2.ImmCost, C2.SetupCost);
  }

  int adjustInliningThreshold(const CallBase *CB) const override;

  void getUnrollingPreferences(Loop *L, ScalarEvolution &SE,
                               TTI::UnrollingPreferences &UP,
                               OptimizationRemarkEmitter *ORE) const override;

  bool isProfitableToSinkOperands(Instruction *I,
                                  SmallVectorImpl<Use *> &Ops) const override {

    if (!I->getFunction()->hasOptSize())
      return false;

    for (unsigned i = 0; i < I->getNumOperands(); ++i) {
      bool operandValid = true;
      if (auto UI = dyn_cast<Instruction>(I->getOperandUse(i))) {

        if (UI->getOpcode() == Instruction::Call ||
            UI->getOpcode() == Instruction::Load ||
            UI->getOpcode() == Instruction::Store ||
            UI->getOpcode() == Instruction::Alloca)
          operandValid = false;

        if (UI->isTerminator() || isa<PHINode>(UI) || UI->isEHPad() ||
            UI->mayThrow())
          operandValid = false;

        for (unsigned j = 0; (j < UI->getNumOperands()) && operandValid; ++j) {
          if (isa<Instruction>(UI->getOperandUse(j)))
            operandValid = false;
        }

        if (operandValid && !UI->hasNUsesOrMore(2))
          Ops.push_back(&I->getOperandUse(i));
      }
    }
    return !Ops.empty();
  }
};

} // end namespace llvm.

#endif
