//===-- RL78ISelLowering.h - RL78 DAG Lowering Interface ------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the interfaces that RL78 uses to lower LLVM code into a
// selection DAG.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RL78_RL78ISELLOWERING_H
#define LLVM_LIB_TARGET_RL78_RL78ISELLOWERING_H

#include "RL78.h"
#include "llvm/CodeGen/TargetLowering.h"

namespace llvm {
class RL78Subtarget;

namespace RL78ISD {
enum NodeType : unsigned {
  FIRST_NUMBER = ISD::BUILTIN_OP_END,
  SEL_RB,
  CMP,
  LOWCMP,
  CALL,
  CALLT,
  TAIL_CALL,
  RET,
  RETI,
  RETB,
  BRCC,
  SELECTCC,
  SELECTCCBTBF,
  BTBF,
  MOV1TOCY,
  MOV1FROMCY,
  LOAD1TOCY,
  STORE1FROMCY,
  AND1CY,
  OR1CY,
  XOR1CY,
  SET1,
  CLR1,
  NOT1CY,
  // After a compare: CY ^= sign bit of the operand; CY = !CY.
  XORSIGNCY,
  NOTCY,
  DIVWU,
  XCHW,
  LOW8,
  LOW16,
  HI16,
  ANDMEM,
  ORMEM,
  XORMEM,
  MACHU,
  MACH,
  INC,
  // A word shifted to the right by one, the bit that leaves in CY (the
  // glue result): SRLC and SRAC shift a zero or the sign in, RORWC the CY
  // that comes in.
  SRLC,
  SRAC,
  RORWC,
  // The carry into bit 15 of a word (glue operand).
  CY15,
  LOAD_SELECTCC,
  DELAY_CYCLES_1_4,
  DELAY_CYCLES_5,
  DELAY_CYCLES_6_1279,
};
}

class RL78TargetLowering : public TargetLowering {
  const RL78Subtarget *Subtarget;

public:
  RL78TargetLowering(const TargetMachine &TM, const RL78Subtarget &STI);

  SDValue LowerOperation(SDValue Op, SelectionDAG &DAG) const override;
  SDValue PerformDAGCombine(SDNode *N, DAGCombinerInfo &DCI) const override;

  bool
  splitValueIntoRegisterParts(SelectionDAG &DAG, const SDLoc &DL, SDValue Val,
                              SDValue *Parts, unsigned NumParts, MVT PartVT,
                              std::optional<CallingConv::ID> CC) const override;

  bool useSoftFloat() const override;

  // Not a TargetLowering hook any more (removed upstream); see PORT-23.md.
  bool ExpandInlineAsm(CallInst *) const;

  unsigned getJumpTableEncoding() const override;

  bool areJTsAllowed(const Function *Fn) const override;

  void getTgtMemIntrinsic(SmallVectorImpl<IntrinsicInfo> &Infos,
                          const CallBase &I, MachineFunction &MF,
                          unsigned Intrinsic) const override;

  /// computeKnownBitsForTargetNode - Determine which of the bits specified
  /// in Mask are known to be either zero or one and return them in the
  /// KnownZero/KnownOne bitsets.
  void computeKnownBitsForTargetNode(const SDValue Op, KnownBits &Known,
                                     const APInt &DemandedElts,
                                     const SelectionDAG &DAG,
                                     unsigned Depth = 0) const override;

  MachineBasicBlock *
  EmitInstrWithCustomInserter(MachineInstr &MI,
                              MachineBasicBlock *MBB) const override;

  const char *getTargetNodeName(unsigned Opcode) const override;

  ConstraintType getConstraintType(StringRef Constraint) const override;

  std::pair<unsigned, const TargetRegisterClass *>
  getRegForInlineAsmConstraint(const TargetRegisterInfo *TRI,
                               StringRef Constraint, MVT VT) const override;

  MVT getScalarShiftAmountTy(const DataLayout &, EVT vt) const override {
    return MVT::i8;
  }

  /// Return the ValueType for comparison libcalls. Comparions libcalls include
  /// floating point comparion calls, and Ordered/Unordered check calls on
  /// floating point numbers.
  MVT::SimpleValueType getCmpLibcallReturnType() const override {
    return MVT::i16;
  }

  Register getRegisterByName(const char *RegName, LLT VT,
                             const MachineFunction &MF) const override;

  bool isSelectSupported(SelectSupportKind Kind) const override;
  bool isLegalAddressingMode(const DataLayout &DL, const AddrMode &AM, Type *Ty,
                             unsigned AS,
                             Instruction *I = nullptr) const override;
  bool shouldFormBranchFromSelects(ArrayRef<SelectInst *> Selects) const override;

  /// getSetCCResultType - Return the ISD::SETCC ValueType
  EVT getSetCCResultType(const DataLayout &DL, LLVMContext &Context,
                         EVT VT) const override;

  bool CanLowerReturn(CallingConv::ID CallConv, MachineFunction &MF,
                      bool isVarArg,
                      const SmallVectorImpl<ISD::OutputArg> &Outs,
                      LLVMContext &Context, const Type *RetTy) const override;

  SDValue LowerFormalArguments(SDValue Chain, CallingConv::ID CallConv,
                               bool isVarArg,
                               const SmallVectorImpl<ISD::InputArg> &Ins,
                               const SDLoc &dl, SelectionDAG &DAG,
                               SmallVectorImpl<SDValue> &InVals) const override;

  SDValue LowerCall(TargetLowering::CallLoweringInfo &CLI,
                    SmallVectorImpl<SDValue> &InVals) const override;

  SDValue LowerReturn(SDValue Chain, CallingConv::ID CallConv, bool isVarArg,
                      const SmallVectorImpl<ISD::OutputArg> &Outs,
                      const SmallVectorImpl<SDValue> &OutVals, const SDLoc &dl,
                      SelectionDAG &DAG) const override;

  EVT getTypeForExtReturn(LLVMContext &Context, EVT VT,
                          ISD::NodeType ExtendKind) const override;

  SDValue LowerMULO(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerRETURNADDR(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerFRAMEADDR(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerExternalSymbol(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerGlobalAddress(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerConstantPool(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerBlockAddress(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerJumpTable(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerLOAD(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerSTORE(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerSETCC(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerDYNAMIC_STACKALLOC(SDValue Op, SelectionDAG &DAG) const;

  SDValue withTargetFlags(SDValue Op, unsigned TF, SelectionDAG &DAG) const;
  SDValue makeAddress(SDValue Op, SelectionDAG &DAG) const;

  void ReplaceNodeResults(SDNode *N, SmallVectorImpl<SDValue> &Results,
                          SelectionDAG &DAG) const override;
  void LowerOperationWrapper(SDNode *N, SmallVectorImpl<SDValue> &Results,
                             SelectionDAG &DAG) const override;

  /// Speculating a call to intrinsic cttz is cheap.
  bool isCheapToSpeculateCttz(Type *Ty) const override { return true; }

  /// Speculating a call to intrinsic ctlz is cheap.
  bool isCheapToSpeculateCtlz(Type *Ty) const override { return true; }

  bool shouldConvertConstantLoadToIntImm(const APInt &Imm,
                                         Type *Ty) const override {
    return true;
  }

  // Hoisting introdcues extra copies, we prefer sinking for RL78.
  bool isProfitableToHoist(Instruction *I) const override { return false; }

  // We have BT/BF.
  bool isMaskAndCmp0FoldingBeneficial(const Instruction &AndI) const override {
    return true;
  }

  // It's always profitable to narrow on RL78.
  bool isNarrowingProfitable(SDNode *N, EVT VT1, EVT VT2) const override {
    return true;
  }

  bool isMultiStoresCheaperThanBitsMerge(EVT LTy, EVT HTy) const override {
    return true;
  }

  bool isTruncateFree(EVT FromVT, EVT ToVT) const override { return true; }

  bool mayBeEmittedAsTailCall(const CallInst *CI) const override {
    return CI->isTailCall();
  }

  ShiftLegalizationStrategy
  preferredShiftLegalizationStrategy(SelectionDAG &DAG, SDNode *N,
                                     unsigned ExpansionFactor) const override {
    return ShiftLegalizationStrategy::LowerToLibcall;
  }

  bool isDesirableToCommuteWithShift(const SDNode *N,
                                             CombineLevel Level) const override;

  MVT getVectorIdxTy(const DataLayout &DL) const { return MVT::i16; }

  bool shouldPreservePtrArith(const Function &F, EVT PtrVT) const override {
    return PtrVT.getSizeInBits() == 32;
  }

private:
  // CC-RL calling convention specific operand allocator functions
  void
  AnalyzeCCRLCallOperands(CCState &State,
                          const SmallVectorImpl<ISD::OutputArg> &Outs) const;
  void
  AnalyzeCCRLFormalOperands(CCState &State,
                            const SmallVectorImpl<ISD::InputArg> &Outs) const;
  template <typename T>
  void AnalyzeCCRLReturnOperands(CCState &State,
                                 const SmallVectorImpl<T> &Outs) const;

  // lower a library call for the specified, pseudo, op
  SDValue LowerLibCall(SDValue Op, SelectionDAG &DAG,
                       const char *libFunctionName, bool IsSigned,
                       unsigned OperandIndex = 0) const;
  SDValue LowerLibCall(SDValue Op, SelectionDAG &DAG,
                       const char *libFunctionName, bool IsSigned,
                       ArrayRef<SDValue> Ops) const;
  SDValue LowerLibCallVoid(SDValue Op, SelectionDAG &DAG,
                           const char *libFunctionName, bool OpsIsSigned,
                           ArrayRef<SDValue> Ops) const;

  SDValue LowerMul(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerAndOrXor(SDValue Op, SelectionDAG &DAG,
                        unsigned int opcode) const;
  SDValue LowerCDIV(SDValue Op, SelectionDAG &DAG, unsigned int opcode) const;
  SDValue LowerShift(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerRotate(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerIntrinsicWithChain(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerIntrinsicWithoutChain(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerIntrinsicVoid(SDValue Op, SelectionDAG &DAG) const;

  SDValue PerformBRCCCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformBRCONDCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformMULCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformUDIVREMCombine(SDNode *N, DAGCombinerInfo &DCI,
                                ISD::NodeType otherNodeType) const;
  SDValue PerformADDCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformSUBCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformMULADDCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformXORAddCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformTruncateCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformANDCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformORCombine(SDNode *N, DAGCombinerInfo &DCI) const;
  SDValue PerformSHLCombine(SDNode *N, DAGCombinerInfo &DCI) const;

  MachineBasicBlock *LowerEXTEND(bool sext, MachineInstr &MI,
                                 MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerADDE_SUBE_rp_rp(unsigned int opcode, MachineInstr &MI,
                                          MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerADDE_SUBE_rp_imm(unsigned int opcode,
                                           MachineInstr &MI,
                                           MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerADDE_SUBE_rp_memri(unsigned int opcode,
                                             MachineInstr &MI,
                                             MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerADDE_SUBE_rp_abs16(unsigned int opcode,
                                             MachineInstr &MI,
                                             MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerAndOrXor16_rp_imm(unsigned int opcode,
                                            MachineInstr &MI,
                                            MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerAndOrXor16_rp_rp(unsigned int opcode,
                                           MachineInstr &MI,
                                           MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerAndOrXor16_rp_memri(unsigned int opcode,
                                              unsigned int opcode2,
                                              MachineInstr &MI,
                                              MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerAndOrXor16_rp_abs16(unsigned int opcode,
                                              MachineInstr &MI,
                                              MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerSignedCMP0(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerCMP0(MachineInstr &MI, MachineBasicBlock *BB) const;

  MachineBasicBlock *LowerSignedCMP(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerCMPOps(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerCMP(MachineInstr &MI, MachineBasicBlock *BB) const;

  MachineBasicBlock *LowerSignedCMPW(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerCMPWOps(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerCMPW(MachineInstr &MI, MachineBasicBlock *BB) const;

  MachineBasicBlock *LowerSignedCMPWMem(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerCMPWMemOps(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerCMPWMem(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerSELECTCC(bool isI8, MachineInstr &MI,
                                   MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerLOAD_SELECTCC(MachineInstr &MI,
                                        MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerMUL8(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerShift_Or_LowerRotate_rp_rp(MachineInstr &MI,
                                                     MachineBasicBlock *BB,
                                                     unsigned int opcode,
                                                     bool isI8) const;
  MachineBasicBlock *LowerMUL8Zext16(MachineInstr &MI,
                                     MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerUMUL_LOHI16(MachineInstr &MI,
                                      MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerMULDIV16(MachineInstr &MI, MachineBasicBlock *BB,
                                   unsigned srcIndex) const;
  MachineBasicBlock *LowerDIVWU(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *Lower8BitOpAA(MachineInstr &MI,
                                   MachineBasicBlock *BB) const;
  MachineBasicBlock *Lower16BitOpAXAX(MachineInstr &MI,
                                      MachineBasicBlock *BB) const;
  MachineBasicBlock *Lower8bitADst(MachineInstr &MI,
                                   MachineBasicBlock *BB) const;
  MachineBasicBlock *Lower16bitAXDst(MachineInstr &MI,
                                     MachineBasicBlock *BB) const;
  MachineBasicBlock *Lower8bitASrc(MachineInstr &MI, MachineBasicBlock *BB,
                                   unsigned OpNum = 0,
                                   unsigned Reg = RL78::R1) const;
  MachineBasicBlock *Lower16bitAXSrc(MachineInstr &MI, MachineBasicBlock *BB,
                                     unsigned OpNum = 0,
                                     unsigned Reg = RL78::RP0) const;
  MachineBasicBlock *LowerESSrc(MachineInstr &MI, MachineBasicBlock *BB,
                                unsigned OpNum) const;
  MachineBasicBlock *LowerCallCSRP(MachineInstr &MI,
                                   MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerBSWAP32(MachineInstr &MI,
                                  MachineBasicBlock *BB) const;
  MachineBasicBlock *LowerToHLByteOrWordBC(unsigned ImmPos, unsigned RegPos,
                                           MachineInstr &MI,
                                           MachineBasicBlock *BB) const;
  bool decomposeMulByConstant(LLVMContext &Context, EVT VT,
                              SDValue C) const override;
};
} // end namespace llvm

#endif // RL78_ISELLOWERING_H
