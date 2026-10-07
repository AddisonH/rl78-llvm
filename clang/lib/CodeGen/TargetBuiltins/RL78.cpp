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
  case RL78::BI__EI:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_ei));
  case RL78::BI__builtin_rl78_di:
  case RL78::BI__DI:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_di));
  case RL78::BI__halt:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_halt));
  case RL78::BI__stop:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_stop));
  case RL78::BI__nop:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_nop));
  case RL78::BI__brk:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_brk));
  case RL78::BI__builtin_rl78_pswie:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_pswie));
  case RL78::BI__builtin_rl78_getpswisp:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_getpswisp));
  case RL78::BI__get_psw:
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_getpsw));
  case RL78::BI__set_psw:
  case RL78::BI__builtin_rl78_setpswisp:
  case RL78::BI__builtin_rl78_ror1:
  case RL78::BI__builtin_rl78_rol1: {
    Value *ArgValue = EmitScalarExpr(E->getArg(0));
    switch (BuiltinID) {
    case RL78::BI__builtin_rl78_setpswisp:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_setpswisp),
                              {ArgValue});
    case RL78::BI__set_psw:
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
    if (!E->getArg(0)->getType()->isPointerType() ||
        E->getArg(0)->getType()->getPointeeType().getAddressSpace() ==
            LangAS::__far_data ||
        (getLangOpts().RenesasRL78DataModel &&
         E->getArg(0)->getType()->getPointeeType().getAddressSpace() ==
             LangAS::Default))
      CGM.Error(E->getArg(0)->getExprLoc(), "argument is not a near pointer");
    if (!E->getArg(1)->isConstantInitializer(getContext(), false, &Culprit))
      CGM.Error(E->getArg(1)->getExprLoc(), "argument is not a compile-time constant");
    if (!E->getArg(3)->isConstantInitializer(getContext(), false, &Culprit))
      CGM.Error(E->getArg(3)->getExprLoc(), "argument is not a compile-time constant");

    // If the pointer has an an explicit near qualifier, we discard it so we
    // don't get parameter type matching errors
    // Later edit: For -mfar-data, as the pointer in the default AS is far,
    // don't remove the near address space
    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    if (E->getArg(0)->getType()->getPointeeType().hasAddressSpace() &&
        !getLangOpts().RenesasRL78DataModel)
      ArgValue0 = Builder.CreatePointerBitCastOrAddrSpaceCast(
          ArgValue0, llvm::PointerType::get(getLLVMContext(), /*AddrSpace=*/0));
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
  case RL78::BI__set1:
  case RL78::BI__builtin_rl78_clr1:
  case RL78::BI__clr1:
  case RL78::BI__builtin_rl78_not1:
  case RL78::BI__not1: {
    const Expr *Culprit;
    if (!E->getArg(1)->isConstantInitializer(getContext(), false, &Culprit))
      CGM.Error(E->getArg(1)->getExprLoc(),
                "argument is not a compile-time constant");
    if (!E->getArg(0)->getType()->isPointerType() ||
        E->getArg(0)->getType()->getPointeeType().getAddressSpace() ==
            LangAS::__far_data ||
        E->getArg(0)->getType()->getPointeeType().getAddressSpace() ==
            LangAS::__far_code ||
        (getLangOpts().RenesasRL78DataModel &&
         E->getArg(0)->getType()->getPointeeType().getAddressSpace() ==
             LangAS::Default))
      CGM.Error(E->getArg(0)->getExprLoc(), "argument is not a near pointer");

    // If the pointer has an an explicit near qualifier, we discard it so we
    // don't get parameter type matching errors
    // Later edit: For -mfar-data, as the pointer in the default AS is far,
    // don't remove the near address space
    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    if (E->getArg(0)->getType()->getPointeeType().hasAddressSpace() &&
        !getLangOpts().RenesasRL78DataModel)
        ArgValue0 = Builder.CreatePointerBitCastOrAddrSpaceCast(
          ArgValue0, llvm::PointerType::get(getLLVMContext(), /*AddrSpace=*/0));
    Value *ArgValue1 = EmitScalarExpr(E->getArg(1));

    auto PtrTy = ArgValue0->getType();
    switch (BuiltinID) {
    case RL78::BI__builtin_rl78_set1:
    case RL78::BI__set1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_set1, PtrTy),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_clr1:
    case RL78::BI__clr1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_clr1, PtrTy),
                                {ArgValue0, ArgValue1});
    case RL78::BI__builtin_rl78_not1:
    case RL78::BI__not1:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_not1, PtrTy),
                                {ArgValue0, ArgValue1});
    default:
      llvm_unreachable("unexpected builtin ID");
    }
  }
  case RL78::BI__rolb:
  case RL78::BI__rorb:
  case RL78::BI__rorw:
  case RL78::BI__rolw:
  case RL78::BI__mulu:
  case RL78::BI__mului:
  case RL78::BI__mulsi:
  case RL78::BI__mulul:
  case RL78::BI__mulsl:
  case RL78::BI__divui:
  case RL78::BI__divul:
  case RL78::BI__remui:
  case RL78::BI__remul: {
    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    Value *ArgValue1 = EmitScalarExpr(E->getArg(1));
    switch (BuiltinID) {
    case RL78::BI__rolb:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_rolb),
                                {ArgValue0, ArgValue1});
    case RL78::BI__rorb:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_rorb),
                                {ArgValue0, ArgValue1});
    case RL78::BI__rorw:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_rorw),
                                {ArgValue0, ArgValue1});
    case RL78::BI__rolw:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_rolw),
                                {ArgValue0, ArgValue1});
    case RL78::BI__mulu:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mulu),
                                {ArgValue0, ArgValue1});
    case RL78::BI__mului:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mului),
                                {ArgValue0, ArgValue1});
    case RL78::BI__mulsi:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mulsi),
                                {ArgValue0, ArgValue1});
    case RL78::BI__mulul:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mulul),
                                {ArgValue0, ArgValue1});
    case RL78::BI__mulsl:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_mulsl),
                                {ArgValue0, ArgValue1});
    case RL78::BI__divui:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_divui),
                                {ArgValue0, ArgValue1});
    case RL78::BI__divul:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_divul),
                                {ArgValue0, ArgValue1});
    case RL78::BI__remui:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_remui),
                                {ArgValue0, ArgValue1});
    case RL78::BI__remul:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_remul),
                                {ArgValue0, ArgValue1});
    default:
      llvm_unreachable("unexpected builtin ID");
    }
  }
  case RL78::BI__macui:
  case RL78::BI__macsi: {
    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    Value *ArgValue1 = EmitScalarExpr(E->getArg(1));
    Value *ArgValue2 = EmitScalarExpr(E->getArg(2));
    switch (BuiltinID) {
    case RL78::BI__macui:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_macui),
                                {ArgValue0, ArgValue1, ArgValue2});
    case RL78::BI__macsi:
      return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_macsi),
                                {ArgValue0, ArgValue1, ArgValue2});
    default:
      llvm_unreachable("unexpected builtin ID");
    }
  }
  case RL78::BI__delay_cycles: {
    Value *ArgValue0 = EmitScalarExpr(E->getArg(0));
    return Builder.CreateCall(CGM.getIntrinsic(Intrinsic::rl78_delay_cycles),
                              {ArgValue0});
  }
  default:
    llvm_unreachable("unexpected builtin ID");
  }
  return nullptr;
}
