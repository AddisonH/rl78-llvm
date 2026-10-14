//===-- RL78RegisterInfo.h - RL78 Register Information Impl ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the RL78 implementation of the TargetRegisterInfo class.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RL78_RL78REGISTERINFO_H
#define LLVM_LIB_TARGET_RL78_RL78REGISTERINFO_H

#define GET_REGINFO_HEADER
#include "RL78GenRegisterInfo.inc"

namespace llvm {
struct RL78RegisterInfo : public RL78GenRegisterInfo {
  RL78RegisterInfo();

  /// Code Generation virtual methods...
  const MCPhysReg *getCalleeSavedRegs(const MachineFunction *MF) const override;
  const uint32_t *getCallPreservedMask(const MachineFunction &MF,
                                       CallingConv::ID CC) const override;

  BitVector getReservedRegs(const MachineFunction &MF) const override;

  const TargetRegisterClass *
  getPointerRegClass(unsigned Kind = 0) const override;

  bool eliminateFrameIndex(MachineBasicBlock::iterator II, int SPAdj,
                           unsigned FIOperandNum,
                           RegScavenger *RS = nullptr) const override;

  Register getFrameRegister(const MachineFunction &MF) const override;

  bool trackLivenessAfterRegAlloc(const MachineFunction &MF) const override {
    return true;
  }

  /// Allow the target to reverse allocation order of local live ranges. This
  /// will generally allocate shorter local live ranges first. For targets with
  /// many registers, this could reduce regalloc compile time by a large
  /// factor.
  bool reverseLocalAssignment() const override { return true; }

  // No region splitting: see the definition.
  bool shouldLocalSplitForVirtReg(const MachineFunction &MF,
                                  const LiveInterval &VirtReg) const override;
  bool shouldRegionSplitForVirtReg(const MachineFunction &MF,
                                   const LiveInterval &VirtReg) const override;

  const TargetRegisterClass *
  getLargestLegalSuperClass(const TargetRegisterClass *RC,
                            const MachineFunction &MF) const override;

  float getSpillWeightScaleFactor(const TargetRegisterClass *RC) const override;

  /// True for the classes of one or a few registers that an instruction
  /// may need an operand in (A, AX, HL, B or C, ...): a value of such a
  /// class is kept next to that instruction.
  bool isSmallClass(const TargetRegisterClass *RC) const;

  /// Hints the register that a value is copied to or from when that copy's
  /// other side can only be one register (the operand of an instruction
  /// that takes HL, BC, B, ...).
  bool getRegAllocationHints(Register VirtReg, ArrayRef<MCPhysReg> Order,
                             SmallVectorImpl<MCPhysReg> &Hints,
                             const MachineFunction &MF, const VirtRegMap *VRM,
                             const LiveRegMatrix *Matrix) const override;

  bool shouldCoalesce(MachineInstr *MI, const TargetRegisterClass *SrcRC,
                      unsigned SubReg, const TargetRegisterClass *DstRC,
                      unsigned DstSubReg, const TargetRegisterClass *NewRC,
                      LiveIntervals &LIS) const override;
};

} // end namespace llvm

#endif
