//===-- RL78RegisterInfo.cpp - RL78 Register Information ----------------===//
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

#include "RL78Subtarget.h"
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/MachineFrameInfo.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-reginfo"

#define GET_REGINFO_TARGET_DESC
#include "RL78GenRegisterInfo.inc"

// OBS. Return address is saved on the stack (CFA-4) however:
// 1. we set RA = PCreg just like GCC so we don't need to make changes in GDB.
// 2. we emit a DW_CFA_offset: r37 at cfa-4 in the CIE.
RL78RegisterInfo::RL78RegisterInfo() : RL78GenRegisterInfo(RL78::PCreg) {}

// A value split away from the instruction that needs it in a particular
// register (A, AX, HL, B or C, ...) may live in any register (pair).
//
// Transitional: only for the classes that hardware definitions alone use.
// The older definitions give some operands a wider class than the
// instruction encodes, and code generation protects those values with
// RL78BCDEHL (RL78AdjustMemRefs): a piece split from such a value must keep
// the class.
const TargetRegisterClass *
RL78RegisterInfo::getLargestLegalSuperClass(const TargetRegisterClass *RC,
                                            const MachineFunction &MF) const {
  switch (RC->getID()) {
  case RL78::RL78AXRPRegClassID:
  case RL78::RL78HLRegClassID:
  case RL78::RL78BCRPRegClassID:
  case RL78::RL78DERPRegClassID:
  case RL78::RL78DEHLRegClassID:
  case RL78::RL78AXBCRPRegClassID:
    return &RL78::RL78RPRegsRegClass;
  case RL78::RL78ARegRegClassID:
  case RL78::RL78XRegRegClassID:
  case RL78::RL78BCRegRegClassID:
  case RL78::RL78BReg8RegClassID:
  case RL78::RL78CReg8RegClassID:
  case RL78::RL78XBCEDHLRegRegClassID:
  case RL78::RL78LowRegClassID:
  case RL78::RL78ABCRegRegClassID:
    return &RL78::RL78RegRegClass;
  }
  return RC;
}

static cl::opt<float> RL78AccSpillScale(
    "rl78-acc-spill-scale", cl::Hidden, cl::init(4.0),
    cl::desc("Spill weight scale for values that must be in AX or A"));

// A value that can only be in AX (or A) has nowhere else to go, while the
// values competing for AX usually do: let it evict them rather than be split
// or spilled itself.
float RL78RegisterInfo::getSpillWeightScaleFactor(
    const TargetRegisterClass *RC) const {
  if (RC->getNumRegs() == 1)
    return RL78AccSpillScale;
  return 1.0;
}

// Joining a copy narrows the joined value to the class both ends allow. When
// that is one of the small classes (A, AX, HL, B or C, ...) the whole value
// would have to stay in those registers, and whatever else needs them while
// it lives has nowhere to go: the allocator can run out of registers. Keep a
// constrained value as short as RL78SplitConstrainedValues made it; the copy
// stays, with the allocator's hints to make it a no-op where the register is
// free. (Joining where it is provably free is a later optimisation.)
bool RL78RegisterInfo::shouldCoalesce(
    MachineInstr *MI, const TargetRegisterClass *SrcRC, unsigned SubReg,
    const TargetRegisterClass *DstRC, unsigned DstSubReg,
    const TargetRegisterClass *NewRC, LiveIntervals &LIS) const {
  const MachineFunction &MF = *MI->getMF();
  auto IsSmall = [&](const TargetRegisterClass *RC) {
    return getLargestLegalSuperClass(RC, MF) != RC;
  };
  if (!IsSmall(NewRC))
    return true;
  // The copy two-address lowering makes for a tied operand joins two
  // constrained values next to one instruction.
  return IsSmall(SrcRC) && IsSmall(DstRC) && !SubReg && !DstSubReg;
}

const MCPhysReg *
RL78RegisterInfo::getCalleeSavedRegs(const MachineFunction *MF) const {
  return CSR_SaveList;
}

const uint32_t *
RL78RegisterInfo::getCallPreservedMask(const MachineFunction &MF,
                                       CallingConv::ID CC) const {
  return CSR_RegMask;
}

/// Returns a bitset indexed by physical register number indicating if a
/// register is a special register that has particular uses and should be
/// considered unavailable at all times, e.g. stack pointer, return address.
/// A reserved register:
/// - is not allocatable
/// - is considered always live
/// - is ignored by liveness tracking
/// It is often necessary to reserve the super registers of a reserved
/// register as well, to avoid them getting allocated indirectly. You may use
/// markSuperRegs() and checkAllSuperRegsMarked() in this case.
BitVector RL78RegisterInfo::getReservedRegs(const MachineFunction &MF) const {
  BitVector Reserved(getNumRegs());
  Reserved.set(RL78::SPreg);
  Reserved.set(RL78::ES);

  return Reserved;
}

/// Returns a TargetRegisterClass used for pointer values.
/// If a target supports multiple different pointer register classes,
/// kind specifies which one is indicated.
const TargetRegisterClass *
RL78RegisterInfo::getPointerRegClass(unsigned Kind) const {
  return &RL78::RL78RPRegsRegClass;
}

void buildWordBCAccess(MachineBasicBlock &MBB, MachineFunction &MF,
                       const TargetFrameLowering *TFI,
                       MachineBasicBlock::iterator &II, DebugLoc &DL,
                       const TargetInstrInfo *TII, bool isLoad, bool is8bit,
                       unsigned int FrameReg, unsigned int offset,
                       unsigned char offsetAdj = 0, bool saveBC = true) {

  if (FrameReg == RL78::SPreg) {
    offset += offsetAdj;
  }

  if (saveBC) {
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp_cg))
        .addReg(RL78::RP2, RegState::Kill);
    if (FrameReg == RL78::SPreg) {
      offset = offset + 2;
    }
  }

  BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::RP2).addReg(FrameReg);

  if (isLoad) {
    BuildMI(MBB, II, DL,
            TII->get(is8bit ? RL78::LOAD8_r_ri : RL78::LOAD16_rp_rpi),
            is8bit ? RL78::R1 : RL78::RP0)
        .addReg(RL78::RP2)
        .addImm(offset);
  } else {
    BuildMI(MBB, II, DL,
            TII->get(is8bit ? RL78::STORE8_ri_r : RL78::STORE16_rpi_rp))
        .addReg(RL78::RP2)
        .addImm(offset)
        .addReg(is8bit ? RL78::R1 : RL78::RP0);
  }

  if (saveBC) {
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp_cg), RL78::RP2);
  }
}

void build16bitAccess(MachineBasicBlock &MBB, MachineFunction &MF,
                      MachineInstr &MI, const TargetFrameLowering *TFI,
                      MachineBasicBlock::iterator &II, DebugLoc &DL,
                      const TargetInstrInfo *TII, unsigned int FrameReg,
                      unsigned int Offset) {
  unsigned int opCode = MI.getOpcode();
  bool is8bit = (opCode == RL78::LOAD8_r_stack_slot) ||
                (opCode == RL78::STORE8_stack_slot_r) ||
                (opCode == RL78::MOV_A_mSPi) || (opCode == RL78::MOV_mSPi_A);
  bool isLoad = ((opCode == RL78::LOAD8_r_stack_slot) ||
                 (opCode == RL78::LOAD16_rp_stack_slot) ||
                 (opCode == RL78::MOV_A_mSPi) ||
                 (opCode == RL78::MOVW_AX_mSPi));
  llvm::Register mainRegister =
      isLoad ? MI.getOperand(0).getReg() : MI.getOperand(2).getReg();
  if (mainRegister == RL78::RP0 || mainRegister == RL78::R1) {
    // PUSH BC.
    // MOVW BC, FrameReg.
    // LOAD/STORE AX/A from/to Offset+2[BC].
    // POP BC.
    buildWordBCAccess(MBB, MF, TFI, II, DL, TII, isLoad, is8bit, FrameReg,
                      Offset);
  } else if (mainRegister == RL78::RP2) {
    // PUSH AX.
    // if store MOVW AX, BC.
    // MOVW BC, FrameReg.
    // LOAD/STORE AX/A from/to Offset+2[BC].
    // MOVW BC, AX.
    // POP AX.
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp_cg))
        .addReg(RL78::RP0, RegState::Kill);
    if (!isLoad) {
      BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::RP0)
          .addReg(mainRegister, RegState::Kill);
    }
    buildWordBCAccess(MBB, MF, TFI, II, DL, TII, isLoad, false, FrameReg,
                      Offset, 2, false);
    BuildMI(MBB, II, DL, TII->get(RL78::COPY), mainRegister)
        .addReg(RL78::RP0, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp_cg), RL78::RP0);
  } else if (mainRegister == RL78::RP4 ||
             (mainRegister == RL78::RP6 && FrameReg != RL78::RP6)) {
    // if mainRegister == DE/HL and we don't try to store HL to [HL+offset].
    // XCHW AX, DE/HL.
    // PUSH BC.
    // MOVW BC, FrameReg.
    // LOAD/STORE AX/A from/to Offset+2[BC].
    // POP BC.
    // XCHW AX, DE/HL.
    BuildMI(MBB, II, DL, TII->get(RL78::XCHW_AX_rp_cg), RL78::RP0)
        .addReg(mainRegister, RegState::Define)
        .addReg(RL78::RP0, RegState::Kill)
        .addReg(mainRegister, RegState::Kill);
    buildWordBCAccess(MBB, MF, TFI, II, DL, TII, isLoad, is8bit, FrameReg,
                      Offset);
    BuildMI(MBB, II, DL, TII->get(RL78::XCHW_AX_rp_cg), RL78::RP0)
        .addReg(mainRegister, RegState::Define)
        .addReg(RL78::RP0, RegState::Kill)
        .addReg(mainRegister, RegState::Kill);
  } else if ((mainRegister == RL78::R0) && isLoad) {
    // PUSH DE.
    // COPY E, A.
    // PUSH BC.
    // MOVW BC, FrameReg.
    // LOAD A from Offset+4[BC].
    // POP BC.
    // COPY X, A.
    // COPY A, E.
    // POP DE.
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp_cg))
        .addReg(RL78::RP4, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::R4)
        .addReg(RL78::R1, RegState::Kill);
    buildWordBCAccess(MBB, MF, TFI, II, DL, TII, isLoad, is8bit, FrameReg,
                      Offset, 2);
    BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::R0)
        .addReg(RL78::R1, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::R1)
        .addReg(RL78::R4, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp_cg), RL78::RP4);
  } else {
    // PUSH AX.
    // if store COPY AX/A, mainRegister.
    // PUSH BC.
    // MOVW BC, FrameReg.
    // LOAD/STORE AX/A from/to Offset+4[BC].
    // POP BC.
    // if load COPY mainRegister, AX/A.
    // POP AX.
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp_cg))
        .addReg(RL78::RP0, RegState::Kill);
    if (!isLoad) {
      BuildMI(MBB, II, DL, TII->get(RL78::COPY), is8bit ? RL78::R1 : RL78::RP0)
          .addReg(mainRegister, RegState::Kill);
    }
    buildWordBCAccess(MBB, MF, TFI, II, DL, TII, isLoad, is8bit, FrameReg,
                      Offset, 2);
    if (isLoad) {
      BuildMI(MBB, II, DL, TII->get(RL78::COPY), mainRegister)
          .addReg(is8bit ? RL78::R1 : RL78::RP0, RegState::Kill);
    }
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp_cg), RL78::RP0);
  }

  MI.eraseFromParent();
}

static void loadUnalignedSP(MachineBasicBlock &MBB,
                            MachineBasicBlock::iterator II, DebugLoc &DL,
                            const TargetInstrInfo *TII,
                            unsigned int actualFrameReg, unsigned int offset) {

  if (isUInt<8>(offset))
    BuildMI(MBB, II, DL, TII->get(RL78::LOAD16_rp_stack_slot), RL78::RP0)
        .addReg(actualFrameReg)
        .addImm(offset);
  else if (isUInt<16>(offset + 2)) {
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp_cg))
        .addReg(RL78::RP2, RegState::Kill);
    unsigned additionalAdj = 0;
    if (actualFrameReg == RL78::SPreg) {
      BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_sp), RL78::RP0)
          .addReg(actualFrameReg);
      additionalAdj = 2;
      // If we are using SP, account for the bc push.
    } else
      BuildMI(MBB, II, DL, TII->get(RL78::MOVW_AX_rp_cg), RL78::RP0)
          .addReg(actualFrameReg);

    BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_AX_cg), RL78::RP2)
        .addReg(RL78::RP0, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::LOAD16_rp_rpi), RL78::RP0)
        .addReg(RL78::RP2, RegState::Kill)
        .addImm(offset + additionalAdj);
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp_cg), RL78::RP2);
  } else
    llvm_unreachable("Invalid stack offset!");
}

/// This method must be overriden to eliminate abstract frame indices from
/// instructions which may use them. The instruction referenced by the
/// iterator contains an MO_FrameIndex operand which must be eliminated by
/// this method. This method may modify or replace the specified instruction,
/// as long as it keeps the iterator pointing at the finished product.
/// SPAdj is the SP adjustment due to call frame setup instruction.
/// FIOperandNum is the FI operand number.
/// Returns true if the current instruction was removed and the iterator
/// is not longer valid
bool RL78RegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator II,
                                           int SPAdj, unsigned FIOperandNum,
                                           RegScavenger *RS) const {
  MachineInstr &MI = *II;
  MachineFunction &MF = *MI.getParent()->getParent();
  MachineBasicBlock &MBB = *MI.getParent();
  const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();
  const TargetFrameLowering *TFI = MF.getSubtarget().getFrameLowering();
  DebugLoc DL = MI.getDebugLoc();
  int FrameIndex = MI.getOperand(FIOperandNum).getIndex();

  Register FrameReg;
  int64_t Offset = TFI->getFrameIndexReference(MF, FrameIndex, FrameReg).getFixed();
  Offset += MI.getOperand(FIOperandNum + 1).getImm();

  unsigned actualFrameReg =
      MF.getSubtarget<RL78Subtarget>().getRegisterInfo()->getFrameRegister(MF);
  int stackSize = MF.getFrameInfo().getStackSize();

  // MI.dump();
  // MI.getParent()->dump();
  // The hardware [SP+byte] forms become [HL+byte] when the frame is
  // addressed through HL.
  auto UseFrameReg = [&](Register Reg) {
    if (Reg == RL78::SPreg)
      return;
    switch (MI.getOpcode()) {
    case RL78::MOV_A_mSPi:
      MI.setDesc(TII->get(RL78::MOV_A_mRPi));
      break;
    case RL78::MOV_mSPi_A:
      MI.setDesc(TII->get(RL78::MOV_mRPi_A));
      break;
    case RL78::MOV_mSPi_i8:
      MI.setDesc(TII->get(RL78::MOV_mRPi_i8));
      break;
    case RL78::MOVW_AX_mSPi:
      MI.setDesc(TII->get(RL78::MOVW_AX_mRPi));
      break;
    case RL78::MOVW_mSPi_AX:
      MI.setDesc(TII->get(RL78::MOVW_mRPi_AX));
      break;
    }
  };
  bool IsWordLoad = MI.getOpcode() == RL78::LOAD16_rp_stack_slot ||
                    MI.getOpcode() == RL78::MOVW_AX_mSPi;
  if ((MI.getOpcode() == RL78::LOAD8_r_stack_slot) ||
      (MI.getOpcode() == RL78::LOAD16_rp_stack_slot) ||
      (MI.getOpcode() == RL78::STORE8_stack_slot_r) ||
      (MI.getOpcode() == RL78::STORE16_stack_slot_rp) ||
      (MI.getOpcode() == RL78::MOV_A_mSPi) ||
      (MI.getOpcode() == RL78::MOVW_AX_mSPi) ||
      (MI.getOpcode() == RL78::MOV_mSPi_A) ||
      (MI.getOpcode() == RL78::MOVW_mSPi_AX)) {

    int offsetAdj = 0;
    if (FrameReg == RL78::RP4) {
      // It means we first need to retrieve the old SP.
      BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp_cg))
          .addReg(RL78::RP6, RegState::Kill);
      offsetAdj += 2;

      if (!IsWordLoad) {
        BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp_cg))
            .addReg(RL78::RP0, RegState::Kill);
        offsetAdj += 2;
      }

      if (actualFrameReg != RL78::SPreg)
        offsetAdj = 0;

      int stackSize = MF.getFrameInfo().getStackSize();

      loadUnalignedSP(MBB, II, DL, TII, actualFrameReg,
                      stackSize - 2 + offsetAdj);

      BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_AX_cg), RL78::RP6)
          .addReg(RL78::RP0, RegState::Kill);

      if (!IsWordLoad)
        BuildMI(MBB, II, DL, TII->get(RL78::POP_rp_cg), RL78::RP0);

      FrameReg = RL78::RP6;
      BuildMI(MBB, std::next(II), DL, TII->get(RL78::POP_rp_cg), RL78::RP6);
    }

    if (isUInt<8>(Offset + offsetAdj)) {
      UseFrameReg(FrameReg);
      MI.getOperand(FIOperandNum).ChangeToRegister(FrameReg, false);
      MI.getOperand(FIOperandNum + 1).ChangeToImmediate(Offset);
      if (isUInt<8>(Offset + 4))
        MI.getOperand(FIOperandNum + 1).setTargetFlags(SPII::MO_OUTLINE_SP);
      else
        MI.getOperand(FIOperandNum + 1).setTargetFlags(SPII::MO_NO_OUTLINE_SP);
      // MI.getParent()->dump();
      return false;
    }
    else if (isUInt<16>(Offset - 2 + offsetAdj)) {
      build16bitAccess(MBB, MF, MI, TFI, II, DL, TII, FrameReg, Offset);
      return true;
    }
    // This is a 16 bit machine, we shouldn't have a stack offset which is 32
    // bit.
    llvm_unreachable("Invalid stack offset!");
  } else if (MI.getOpcode() == RL78::STORE8_stack_slot_imm ||
             MI.getOpcode() == RL78::MOV_mSPi_i8) {
    if (isUInt<8>(Offset)) {
      UseFrameReg(FrameReg);
      MI.getOperand(FIOperandNum).ChangeToRegister(FrameReg, false);
      MI.getOperand(FIOperandNum + 1).ChangeToImmediate(Offset);
      if (isUInt<8>(Offset + 4))
        MI.getOperand(FIOperandNum + 1).setTargetFlags(SPII::MO_OUTLINE_SP);
      else
        MI.getOperand(FIOperandNum + 1).setTargetFlags(SPII::MO_NO_OUTLINE_SP);
      // MI.getParent()->dump();
      return false;
    } else if (isUInt<16>(Offset - 2)) {
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::PUSH_rp_cg))
          .addReg(RL78::RP2, RegState::Kill);

      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::MOVW_rp_sp), RL78::RP2)
          .addReg(RL78::SPreg);
      Offset += 2;

      // Store using word[BC].
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::STORE8_ri_imm))
          .addReg(RL78::RP2)
          .addImm(Offset)
          .add(MI.getOperand(2));
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::POP_rp_cg), RL78::RP2);

      // MI.getParent()->dump();
      MI.eraseFromParent();
      return true;
    }
    // This is a 16 bit machine, we shouldn't have a stack offset which is 32
    // bit.
    llvm_unreachable("Invalid stack offset!");
  }
  // MOVW_rp_stack_slot.
  else {
    assert(MI.getOpcode() == RL78::MOVW_rp_stack_slot);
    assert(MI.getOperand(0).getReg() == RL78::RP0);

    if (FrameReg == RL78::RP4)
      // It means we want to reference something with the old, unaligned SP.
      loadUnalignedSP(MBB, II, DL, TII, actualFrameReg, stackSize - 2);
    else
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::MOVW_rp_sp), RL78::RP0)
          .addReg(RL78::SPreg);

    if (Offset)
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::ADDW_rp_imm), RL78::RP0)
          .addReg(RL78::RP0)
          .addImm(Offset);
    MI.eraseFromParent();
    return true;
  }
}

Register RL78RegisterInfo::getFrameRegister(const MachineFunction &MF) const {
  return RL78::SPreg;
}
