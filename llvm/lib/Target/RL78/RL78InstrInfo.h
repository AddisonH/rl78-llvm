//===-- RL78InstrInfo.h - RL78 Instruction Information --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the RL78 implementation of the TargetInstrInfo class.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RL78_RL78INSTRINFO_H
#define LLVM_LIB_TARGET_RL78_RL78INSTRINFO_H

#include "RL78RegisterInfo.h"
#include "llvm/CodeGen/TargetInstrInfo.h"

#define GET_INSTRINFO_HEADER
#include "RL78GenInstrInfo.inc"

namespace llvm {

class RL78Subtarget;


class RL78InstrInfo : public RL78GenInstrInfo {
  const RL78RegisterInfo RI;
  const RL78Subtarget &Subtarget;
  virtual void anchor();

protected:
  std::optional<DestSourcePair>
  isCopyInstrImpl(const MachineInstr &MI) const override;

public:
  explicit RL78InstrInfo(RL78Subtarget &ST);

  bool findCommutedOpIndices(const MachineInstr &MI, unsigned &SrcOpIdx1,
                             unsigned &SrcOpIdx2) const override;




  /// XCH A, X has an encoding of its own.
  static unsigned getXCHOpcode(Register Reg) {
    return Reg == RL78::R0 ? RL78::XCH_A_X : RL78::XCH_A_r;
  }

  /// The conditional branch on \p CC: C, NC, Z and NZ are one instruction,
  /// H and NH another.
  static unsigned getBranchOpcode(int64_t CC) {
    return CC == RL78CC::RL78CC_H || CC == RL78CC::RL78CC_NH ? RL78::BHcc_rel8
                                                             : RL78::Bcc_rel8;
  }

  /// The conditional skip on \p CC.
  /// The skip on condition \p CC; with \p Terminator the form that ends a
  /// block (a branch over the next instruction, which is in another block or
  /// is a branch itself).
  static unsigned getSkipOpcode(int64_t CC, bool Terminator = false) {
    if (CC == RL78CC::RL78CC_H || CC == RL78CC::RL78CC_NH)
      return Terminator ? RL78::SKHcc_cg : RL78::SKHcc;
    return Terminator ? RL78::SKcc_cg : RL78::SKcc;
  }

  /// The number of places to the left that ROTL16_r_imm or ROTR16_r_imm
  /// \p MI rotates.
  static unsigned getRotate16Left(const MachineInstr &MI) {
    unsigned Count = MI.getOperand(2).getImm() & 15;
    return MI.getOpcode() == RL78::ROTL16_r_imm ? Count : (16 - Count) & 15;
  }

  /// True if the expansion of the 16-bit rotate \p MI shifts a copy in BC.
  /// The others are one or two steps on AX, with XCH A, X for the eight
  /// places in between.
  static bool rotate16UsesBC(const MachineInstr &MI) {
    switch (getRotate16Left(MI)) {
    case 0:
    case 1:
    case 7:
    case 8:
    case 9:
    case 15:
      return false;
    }
    return true;
  }

  /// Expands the 16-bit pseudos that are two 8-bit operations on AX.
  bool expandWideOnAX(MachineInstr &MI) const;
  bool expandPseudo(MachineInstr &MI) const;
  void buildCopy(MachineBasicBlock &MBB, MachineBasicBlock::iterator I,
                 MachineBasicBlock::iterator After, const DebugLoc &DL,
                 Register DestReg, Register SrcReg, bool KillSrc) const;

  /// getRegisterInfo - TargetInstrInfo is a superset of MRegister info.  As
  /// such, whenever a client has an instance of instruction info, it should
  /// always be able to get register info as well (through this method).
  ///
  const RL78RegisterInfo &getRegisterInfo() const { return RI; }

  /// isLoadFromStackSlot - If the specified machine instruction is a direct
  /// load from a stack slot, return the virtual or physical register number of
  /// the destination along with the FrameIndex of the loaded stack slot.  If
  /// not, return 0.  This predicate must return 0 if the instruction has
  /// any side effects other than loading from the stack slot.
  Register isLoadFromStackSlot(const MachineInstr &MI,
                               int &FrameIndex) const override;

  /// isStoreToStackSlot - If the specified machine instruction is a direct
  /// store to a stack slot, return the virtual or physical register number of
  /// the source reg along with the FrameIndex of the loaded stack slot.  If
  /// not, return 0.  This predicate must return 0 if the instruction has
  /// any side effects other than storing to the stack slot.
  Register isStoreToStackSlot(const MachineInstr &MI,
                              int &FrameIndex) const override;

  bool analyzeBranch(MachineBasicBlock &MBB, MachineBasicBlock *&TBB,
                     MachineBasicBlock *&FBB,
                     SmallVectorImpl<MachineOperand> &Cond,
                     bool AllowModify = false) const override;

  unsigned removeBranch(MachineBasicBlock &MBB,
                        int *BytesRemoved = nullptr) const override;

  unsigned insertBranch(MachineBasicBlock &MBB, MachineBasicBlock *TBB,
                        MachineBasicBlock *FBB, ArrayRef<MachineOperand> Cond,
                        const DebugLoc &DL,
                        int *BytesAdded = nullptr) const override;

  bool
  reverseBranchCondition(SmallVectorImpl<MachineOperand> &Cond) const override;

  void copyPhysReg(MachineBasicBlock &MBB, MachineBasicBlock::iterator I,
                   const DebugLoc &DL, Register DestReg, Register SrcReg,
                   bool KillSrc, bool RenamableDest = false,
                   bool RenamableSrc = false) const override;

  void storeRegToStackSlot(
      MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI, Register SrcReg,
      bool isKill, int FrameIndex, const TargetRegisterClass *RC, Register VReg,
      MachineInstr::MIFlag Flags = MachineInstr::NoFlags) const override;

  void loadRegFromStackSlot(
      MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI, Register DestReg,
      int FrameIndex, const TargetRegisterClass *RC, Register VReg,
      unsigned SubReg = 0,
      MachineInstr::MIFlag Flags = MachineInstr::NoFlags) const override;
  
  bool expandPostRAPseudo(MachineInstr &MI) const override;

  /// Set the flags of the exchange instructions (XCH, XCHW) of \p MBB, and
  /// the kill flags of the block. An exchange often moves one value only:
  /// the half that comes from a register without a value is then an undef
  /// use and a dead definition. \p Ignore is an instruction that is about
  /// to be removed.
  void setExchangeFlags(MachineBasicBlock &MBB,
                        const MachineInstr *Ignore = nullptr) const;

  /// True if \p Reg, or a part of it, has a value that \p I or a later
  /// instruction reads.
  bool isLiveBefore(MachineBasicBlock &MBB, MachineBasicBlock::iterator I,
                    MCRegister Reg) const;

  /// Returns the size in bytes of the specified MachineInstr, or ~0U
  /// when this function is not implemented by a target.
  unsigned getInstSizeInBytes(const MachineInstr &MI) const override;

  /// Returns a \p outliner::OutlinedFunction struct containing target-specific
  /// information for a set of outlining candidates.
  std::optional<std::unique_ptr<outliner::OutlinedFunction>>
  getOutliningCandidateInfo(
      const MachineModuleInfo &MMI,
      std::vector<outliner::Candidate> &RepeatedSequenceLocs,
      unsigned MinRepeats) const override;

  /// Returns how or if \p MI should be outlined.
  outliner::InstrType getOutliningTypeImpl(const MachineModuleInfo &MMI,
                                           MachineBasicBlock::iterator &MIT,
                                           unsigned Flags) const override;

  /// Insert a custom frame for outlined functions.
  void buildOutlinedFrame(MachineBasicBlock &MBB, MachineFunction &MF,
                          const outliner::OutlinedFunction &OF) const override;

  /// Insert a call to an outlined function into the program.
  /// Returns an iterator to the spot where we inserted the call. This must be
  /// implemented by the target.
  MachineBasicBlock::iterator
  insertOutlinedCall(Module &M, MachineBasicBlock &MBB,
                     MachineBasicBlock::iterator &It, MachineFunction &MF,
                     outliner::Candidate &C) const override;

  /// Return true if the function can safely be outlined from.
  /// A function \p MF is considered safe for outlining if an outlined function
  /// produced from instructions in F will produce a program which produces the
  /// same output for any set of given inputs.
  bool isFunctionSafeToOutlineFrom(MachineFunction &MF,
                                   bool OutlineFromLinkOnceODRs) const override;

  /// Return true if the function should be outlined from by default.
  bool shouldOutlineFromFunctionByDefault(MachineFunction &MF) const override;

  /// Return true if the instruction is as cheap as a move instruction.
  ///
  /// Targets for different archs need to override this, and different
  /// micro-architectures can also be finely tuned inside.
  /// For code size improvements, consider that every MachineInstruction is
  /// cheaper than a move.
  bool isAsCheapAsAMove(const MachineInstr &MI) const override {
    return MI.getParent()->getParent()->getFunction().hasOptSize();
  }

  bool isSubregFoldable() const override { return true; }

  ArrayRef<std::pair<unsigned, const char *>>
  getSerializableDirectMachineOperandTargetFlags() const override;

  MachineInstr *foldMemoryOperandImpl(MachineFunction &MF, MachineInstr &MI,
                                      ArrayRef<unsigned> Ops, int FrameIndex,
                                      MachineInstr *&CopyMI,
                                      LiveIntervals *LIS = nullptr,
                                      VirtRegMap *VRM = nullptr) const override;

  bool isReMaterializableImpl(const MachineInstr &MI) const override {
    return true;
  }

  bool hasLowDefLatency(const TargetSchedModel &SchedModel,
                        const MachineInstr &DefMI,
                        unsigned DefIdx) const override {
    // Only DIVHU_cg and DIVWU_cg have high def latency.
    if ((DefMI.getOpcode() == RL78::UDIVREM16_r_r) ||
        (DefMI.getOpcode() == RL78::UDIVREM32_r_r))
      return false;
    return true;
  }

  bool isUnconditionalTailCall(const MachineInstr &MI) const override {
    if ((MI.getOpcode() == RL78::BR_addr16) ||
        (MI.getOpcode() == RL78::BR_addr20))
      return true;
    return false;
  }

  ScheduleHazardRecognizer *
  CreateTargetPostRAHazardRecognizer(const InstrItineraryData *,
                                     const ScheduleDAG *DAG) const override;
};

} // end namespace llvm

#endif
