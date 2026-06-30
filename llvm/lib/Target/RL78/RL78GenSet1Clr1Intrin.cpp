//===- RL78GenSet1Clr1Intrin.cpp - IR-level matcher for builtin clr1/set1 -===//
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
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/PassManager.h"
#include "llvm/IR/PatternMatch.h"
#include "llvm/IR/IntrinsicsRL78.h"
#include "RL78GenSet1Clr1Intrin.h"

using namespace llvm;

static std::pair<int, int> matchSet1(Value *StoredVal, Value *Addr) {
  using namespace PatternMatch;
  ConstantInt *AndVal, *OrVal;

  // Match pattern produced by bitfield assignment.
  if (match(StoredVal,
            m_Or(m_And(m_Load(m_Specific(Addr)), m_ConstantInt(AndVal)),
                 m_ConstantInt(OrVal))) &&
      OrVal->getValue().isPowerOf2() &&
      AndVal->getValue() == (OrVal->getValue() ^ 255))
    return {4, OrVal->getValue().exactLogBase2()};

  // Match pattern produced by and/or-ing with a power of 2.
  if (match(StoredVal, m_Trunc(m_Or(m_ZExt(m_Load(m_Specific(Addr))),
                                    m_ConstantInt(OrVal)))) &&
      OrVal->getValue().isPowerOf2())
    return {5, OrVal->getValue().exactLogBase2()};

  return {};
}

static std::pair<int, int> matchClr1(Value *StoredVal, Value *Addr) {
  using namespace PatternMatch;
  ConstantInt *AndVal, *OrVal;

  // Match pattern produced by bitfield assignment.
  if (match(StoredVal,
            m_Or(m_And(m_Load(m_Specific(Addr)), m_ConstantInt(AndVal)),
                 m_ConstantInt(OrVal))) &&
      (AndVal->getValue() ^ 255).isPowerOf2() && OrVal->isZero())
    return {4, (AndVal->getValue() ^ 255).exactLogBase2()};

  // Match pattern produced by and/or-ing with a power of 2.
  if (match(StoredVal, m_Trunc(m_And(m_ZExt(m_Load(m_Specific(Addr))),
                                     m_ConstantInt(AndVal)))) &&
      (AndVal->getValue() ^ 255).isPowerOf2())
    return {5, (AndVal->getValue() ^ 255).exactLogBase2()};

  return {};
}

PreservedAnalyses
llvm::RL78GenSet1Clr1IntrinPass::run(Function &F, FunctionAnalysisManager &AM) {
  bool Changed = false;

  const DataLayout &DL = F.getParent()->getDataLayout();
  LLVMContext &Ctx = F.getContext();
  IRBuilder<> Builder(Ctx);

  for (auto &BB : F) {
    for (auto I = BB.rbegin(), EI = BB.rend(); I != EI;) {
      // Look for volatile stores as possible pattern endings.
      if (auto *Store = dyn_cast<StoreInst>(&*I++); Store && Store->isVolatile()) {
        Value *StoredVal = Store->getValueOperand();
        Value *Addr = Store->getPointerOperand();

        // Don't bother if not 8-bit with a single use and near address.
        if (!(StoredVal->getType()->isIntegerTy(8) && StoredVal->hasOneUse() &&
              !isa<AllocaInst>(Addr) &&
              DL.getPointerTypeSizeInBits(Addr->getType()) == 16))
          continue;

        bool IsSet = false, IsClr = false;
        int NumInsts, BitNo;

        if (std::tie(NumInsts, BitNo) = matchSet1(StoredVal, Addr); NumInsts)
          IsSet = true;
        else if (std::tie(NumInsts, BitNo) = matchClr1(StoredVal, Addr);
                 NumInsts)
          IsClr = true;

        if (IsSet || IsClr) {
          // Check that all the instructions in the sequence can be deleted.
          auto Count = NumInsts - 1;
          auto J = I;
          for (; J != EI && Count && J->hasOneUse(); ++J, --Count)
            ;
          if (Count)
            continue;

          // Last check: the start of the sequence is a matching load.
          Instruction *MaybeLoad = (J == EI) ? &BB.front() : J->getNextNode();
          auto *Load = dyn_cast<LoadInst>(MaybeLoad);
          if (!(Load && Load->isVolatile() && Load->getType()->isIntegerTy(8) &&
                Load->getPointerOperand() == Addr))
            continue;

          // Add a call to the corresponding intrinsic as a sequence replacement.
          auto Func = Intrinsic::getDeclaration(F.getParent(),
                                                IsClr ? Intrinsic::rl78_clr1
                                                      : Intrinsic::rl78_set1,
                                                Addr->getType());
          Builder.SetInsertPoint(Store->getNextNode());
          Builder.CreateCall(
              Func, {Addr, llvm::ConstantInt::get(Load->getType(), BitNo)});

          // Remove the original instructions sequence.
          for (--I; I != J;)
            dyn_cast<Instruction>(&*I++)->eraseFromParent();

          Changed = true;
        }
      }
    }
  }

  return Changed ? PreservedAnalyses::all() : PreservedAnalyses::none();
}
