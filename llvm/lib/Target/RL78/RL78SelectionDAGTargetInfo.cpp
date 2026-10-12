//==- llvm/lib/Target/RL78/RL78SelectionDAGTargetInfo.h - RL78 SelectionDAG Info
//--*- C++ -*-==//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===---------------------------------------------------------------------------------------===//
//
// This file implements the RL78 specific subclass of SelectionDAGTargetInfo.
//
//===---------------------------------------------------------------------------------------===//

#include "RL78SelectionDAGTargetInfo.h"
#include "RL78.h"
#include "llvm/CodeGen/TargetLowering.h"

using namespace llvm;

RL78SelectionDAGTargetInfo::~RL78SelectionDAGTargetInfo() = default;

// Common implementation for EmitTargetCodeForMemcpy() and EmitTargetCodeForMemmove() below;
// the different elements (i.e. the libcall id and name) are passed as parameters
SDValue
RL78SelectionDAGTargetInfo::EmitTargetCodeForMemcpymove(
    SelectionDAG &DAG, const SDLoc &dl, SDValue Chain, SDValue Op1, SDValue Op2,
    SDValue Op3, bool isVolatile, bool AlwaysInline,
    MachinePointerInfo DstPtrInfo, MachinePointerInfo SrcPtrInfo,
    unsigned LibCall, const char *FarLibCallName) const {
  if (AlwaysInline)
    return SDValue();

  // Emit a library call.
  TargetLowering::ArgListTy Args;

  // With one near and one far pointer the near one is promoted: the library
  // has a routine for two near pointers and one for two far ones
  // (_COM_memcpy_ff).
  if (DAG.getDataLayout().getPointerSizeInBits(DstPtrInfo.getAddrSpace()) !=
      DAG.getDataLayout().getPointerSizeInBits(SrcPtrInfo.getAddrSpace())) {
    const auto nearSeg = DAG.getConstant(0xf, dl, MVT::i16);
    if (DAG.getDataLayout().getPointerSizeInBits(DstPtrInfo.getAddrSpace()) == 16) {
      Op1 = DAG.getNode(ISD::BUILD_PAIR, dl, MVT::i32, Op1, nearSeg);
      DstPtrInfo.AddrSpace = 2;
    }
    if (DAG.getDataLayout().getPointerSizeInBits(SrcPtrInfo.getAddrSpace()) == 16) {
      Op2 = DAG.getNode(ISD::BUILD_PAIR, dl, MVT::i32, Op2, nearSeg);
      SrcPtrInfo.AddrSpace = 2;
    }
  }

  Args.emplace_back(
      Op1, PointerType::get(*DAG.getContext(), DstPtrInfo.getAddrSpace()));
  Args.emplace_back(
      Op2, PointerType::get(*DAG.getContext(), SrcPtrInfo.getAddrSpace()));

  Args.emplace_back(Op3, DAG.getDataLayout().getIntPtrType(*DAG.getContext()));

  const char *libcallName =
      DAG.getDataLayout().getPointerSizeInBits(DstPtrInfo.getAddrSpace()) == 32
          ? FarLibCallName
          : DAG.getTargetLoweringInfo().getLibcallName((RTLIB::Libcall)LibCall);

  TargetLowering::CallLoweringInfo CLI(DAG);
  CLI.setDebugLoc(dl)
      .setChain(Chain)
      .setLibCallee(
          DAG.getTargetLoweringInfo().getLibcallCallingConv(
              (RTLIB::Libcall)LibCall),
          Op1.getValueType().getTypeForEVT(*DAG.getContext()),
          DAG.getExternalSymbol(
              libcallName, DAG.getTargetLoweringInfo().getPointerTy(
                               DAG.getDataLayout(),
                               DAG.getDataLayout().getProgramAddressSpace())),
          std::move(Args))
      .setDiscardResult();

  std::pair<SDValue, SDValue> CallResult =
      DAG.getTargetLoweringInfo().LowerCallTo(CLI);
  return CallResult.second;
}

SDValue RL78SelectionDAGTargetInfo::EmitTargetCodeForMemcpy(
    SelectionDAG &DAG, const SDLoc &dl, SDValue Chain, SDValue Op1, SDValue Op2,
    SDValue Op3, Align DstAlign, Align SrcAlign, bool isVolatile,
    bool AlwaysInline, MachinePointerInfo DstPtrInfo,
    MachinePointerInfo SrcPtrInfo) const {
  return EmitTargetCodeForMemcpymove(
      DAG, dl, Chain, Op1, Op2, Op3, isVolatile, AlwaysInline,
      DstPtrInfo, SrcPtrInfo, RTLIB::MEMCPY, "_COM_memcpy_ff");
}

SDValue RL78SelectionDAGTargetInfo::EmitTargetCodeForMemmove(
    SelectionDAG &DAG, const SDLoc &dl, SDValue Chain, SDValue Op1, SDValue Op2,
    SDValue Op3, Align DstAlign, Align SrcAlign, bool isVolatile,
    MachinePointerInfo DstPtrInfo, MachinePointerInfo SrcPtrInfo) const {
  return EmitTargetCodeForMemcpymove(DAG, dl, Chain, Op1, Op2, Op3,
                                     isVolatile, false, DstPtrInfo, SrcPtrInfo,
                                     RTLIB::MEMMOVE, "_COM_memmove_ff");
}

SDValue RL78SelectionDAGTargetInfo::EmitTargetCodeForMemset(
    SelectionDAG &DAG, const SDLoc &dl, SDValue Chain, SDValue Op1, SDValue Op2,
    SDValue Op3, Align Align, bool isVolatile,  bool AlwaysInline,
    MachinePointerInfo DstPtrInfo) const {

  // Emit a library call.
  TargetLowering::ArgListTy Args;

  Args.emplace_back(
      Op1, PointerType::get(*DAG.getContext(), DstPtrInfo.getAddrSpace()));
  // Here we pass it as i16, despite only the low i8 part being used
  Args.emplace_back(Op2, Type::getInt16Ty(*DAG.getContext()));
  Args.emplace_back(Op3, DAG.getDataLayout().getIntPtrType(*DAG.getContext()));

  const char *libcallName =
      DAG.getDataLayout().getPointerSizeInBits(DstPtrInfo.getAddrSpace()) == 32
          ? "_COM_memset_f"
          : DAG.getTargetLoweringInfo().getLibcallName(RTLIB::MEMSET);

  TargetLowering::CallLoweringInfo CLI(DAG);
  CLI.setDebugLoc(dl)
      .setChain(Chain)
      .setLibCallee(
          DAG.getTargetLoweringInfo().getLibcallCallingConv(RTLIB::MEMSET),
          Op1.getValueType().getTypeForEVT(*DAG.getContext()),
          DAG.getExternalSymbol(
              libcallName, DAG.getTargetLoweringInfo().getPointerTy(
                               DAG.getDataLayout(),
                               DAG.getDataLayout().getProgramAddressSpace())),
          std::move(Args))
      .setDiscardResult();

  std::pair<SDValue, SDValue> CallResult =
      DAG.getTargetLoweringInfo().LowerCallTo(CLI);
  return CallResult.second;
}
