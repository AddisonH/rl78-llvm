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

  const RL78Subtarget *getST() const { return ST; }
  const RL78TargetLowering *getTLI() const { return TLI; }

public:
  explicit RL78TTIImpl(const RL78TargetMachine *TM, const Function &F)
      : BaseT(TM, F.getDataLayout()), ST(TM->getSubtargetImpl(F)),
        TLI(ST->getTargetLowering()) {}

  TTI::MemCmpExpansionOptions
  enableMemCmpExpansion(bool OptSize, bool IsZeroCmp) const override;

  bool hasDivRemOp(Type *DataType, bool IsSigned) const override;

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
          if (auto UI2 = dyn_cast<Instruction>(UI->getOperandUse(j)))
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
