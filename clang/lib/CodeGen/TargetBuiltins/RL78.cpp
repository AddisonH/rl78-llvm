//===------ RL78.cpp - Emit LLVM Code for RL78 builtins -------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This contains code to emit RL78 builtin calls as LLVM code.
//
//===----------------------------------------------------------------------===//

#include "CGBuiltin.h"
#include "clang/Basic/TargetBuiltins.h"
#include "llvm/IR/IntrinsicsRL78.h"

using namespace clang;
using namespace CodeGen;
using namespace llvm;

Value *CodeGenFunction::EmitRL78BuiltinExpr(unsigned BuiltinID,
                                            const CallExpr *E) {
  switch (BuiltinID) {
  case RL78::BI__builtin_rl78_ei:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_ei));
  case RL78::BI__builtin_rl78_di:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_di));
  case RL78::BI__builtin_rl78_halt:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_halt));
  case RL78::BI__builtin_rl78_stop:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_stop));
  case RL78::BI__builtin_rl78_nop:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_nop));
  case RL78::BI__builtin_rl78_brk:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_brk));
  case RL78::BI__builtin_rl78_pswie:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_pswie));
  case RL78::BI__builtin_rl78_getpswisp:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_getpswisp));
  case RL78::BI__builtin_rl78_getpsw:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_getpsw));
  case RL78::BI__builtin_rl78_setpsw:
  case RL78::BI__builtin_rl78_setpswisp:
  case RL78::BI__builtin_rl78_ror1:
  case RL78::BI__builtin_rl78_rol1: {
    Value *ArgValue = EmitScalarExpr(E->getArg(0));
    switch (BuiltinID) {
    case RL78::BI__builtin_rl78_setpswisp:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_setpswisp),
                              {ArgValue});
    case RL78::BI__builtin_rl78_setpsw:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_setpsw),
                              {ArgValue});
    case RL78::BI__builtin_rl78_ror1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_ror1),
                              {ArgValue});
    case RL78::BI__builtin_rl78_rol1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_rol1),
                              {ArgValue});
    default:
      llvm_unreachable("unexpected builtin ID");
    }
  }
  case RL78::BI__builtin_rl78_mov1:
  case RL78::BI__builtin_rl78_and1:
  case RL78::BI__builtin_rl78_or1:
  case RL78::BI__builtin_rl78_xor1: {
    const Expr *Culprit;
    if (!E->getArg(1)->isConstantInitializer(getContext(), false, &Culprit))
      CGM.Error(E->getArg(1)->getExprLoc(), "argument is not a compile-time constant");
    if (!E->getArg(3)->isConstantInitializer(getContext(), false, &Culprit))
      CGM.Error(E->getArg(3)->getExprLoc(), "argument is not a compile-time constant");

    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    Value *ArgValue1 = EmitScalarExpr(E->getArg(1));
    Value *ArgValue2 = EmitScalarExpr(E->getArg(2));
    Value *ArgValue3 = EmitScalarExpr(E->getArg(3));

    auto PtrTy = ArgValue0->getType();
    switch (BuiltinID) {
    case RL78::BI__builtin_rl78_mov1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mov1, PtrTy),
                                {ArgValue0, ArgValue1, ArgValue2, ArgValue3});
    case RL78::BI__builtin_rl78_and1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_and1, PtrTy),
                                {ArgValue0, ArgValue1, ArgValue2, ArgValue3});
    case RL78::BI__builtin_rl78_or1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_or1, PtrTy),
                                {ArgValue0, ArgValue1, ArgValue2, ArgValue3});
    case RL78::BI__builtin_rl78_xor1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_xor1, PtrTy),
                                {ArgValue0, ArgValue1, ArgValue2, ArgValue3});
    default:
      llvm_unreachable("unexpected builtin ID");
    }
  }
  case RL78::BI__builtin_rl78_set1:
  case RL78::BI__builtin_rl78_clr1:
  case RL78::BI__builtin_rl78_not1: {
    const Expr *Culprit;
    if (!E->getArg(1)->isConstantInitializer(getContext(), false, &Culprit))
      CGM.Error(E->getArg(1)->getExprLoc(),
                "argument is not a compile-time constant");

    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    Value *ArgValue1 = EmitScalarExpr(E->getArg(1));

    auto PtrTy = ArgValue0->getType();
    switch (BuiltinID) {
    case RL78::BI__builtin_rl78_set1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_set1, PtrTy),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_clr1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_clr1, PtrTy),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_not1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_not1, PtrTy),
                                {ArgValue0, ArgValue1});
    default:
      llvm_unreachable("unexpected builtin ID");
    }
  }
  case RL78::BI__builtin_rl78_rolb:
  case RL78::BI__builtin_rl78_rorb:
  case RL78::BI__builtin_rl78_rorw:
  case RL78::BI__builtin_rl78_rolw:
  case RL78::BI__builtin_rl78_mulu:
  case RL78::BI__builtin_rl78_mului:
  case RL78::BI__builtin_rl78_mulsi:
  case RL78::BI__builtin_rl78_mulul:
  case RL78::BI__builtin_rl78_mulsl:
  case RL78::BI__builtin_rl78_divui:
  case RL78::BI__builtin_rl78_divul:
  case RL78::BI__builtin_rl78_remui:
  case RL78::BI__builtin_rl78_remul: {
    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    Value *ArgValue1 = EmitScalarExpr(E->getArg(1));
    switch (BuiltinID) {
    case RL78::BI__builtin_rl78_rolb:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_rolb),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_rorb:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_rorb),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_rorw:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_rorw),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_rolw:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_rolw),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_mulu:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mulu),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_mului:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mului),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_mulsi:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mulsi),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_mulul:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mulul),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_mulsl:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mulsl),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_divui:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_divui),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_divul:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_divul),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_remui:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_remui),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_remul:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_remul),
                                {ArgValue0, ArgValue1});
    default:
      llvm_unreachable("unexpected builtin ID");
    }
  }
  case RL78::BI__builtin_rl78_macui:
  case RL78::BI__builtin_rl78_macsi: {
    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    Value *ArgValue1 = EmitScalarExpr(E->getArg(1));
    Value *ArgValue2 = EmitScalarExpr(E->getArg(2));
    switch (BuiltinID) {
    case RL78::BI__builtin_rl78_macui:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_macui),
                                {ArgValue0, ArgValue1, ArgValue2});
    case RL78::BI__builtin_rl78_macsi:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_macsi),
                                {ArgValue0, ArgValue1, ArgValue2});
    default:
      llvm_unreachable("unexpected builtin ID");
    }
  }
  case RL78::BI__builtin_rl78_delay_cycles: {
    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_delay_cycles),
                              {ArgValue0});
  }
  default:
    llvm_unreachable("unexpected builtin ID");
  }
  return nullptr;
}
