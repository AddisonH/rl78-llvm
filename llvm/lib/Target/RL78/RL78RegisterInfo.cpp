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

// A value split away from the instruction that needs it in AX (A) may live in
// any register pair (register).
const TargetRegisterClass *
RL78RegisterInfo::getLargestLegalSuperClass(const TargetRegisterClass *RC,
                                            const MachineFunction &MF) const {
  if (RC == &RL78::RL78AXRPRegClass)
    return &RL78::RL78RPRegsRegClass;
  if (RC == &RL78::RL78ARegRegClass)
    return &RL78::RL78RegRegClass;
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

static cl::opt<bool> RL78AccCoalesce(
    "rl78-acc-coalesce", cl::Hidden, cl::init(false),
    cl::desc("Let the coalescer narrow values to AX or A"));

// Do not narrow a value that may live in any register to the one register an
// accumulator operand (RL78AXRP, RL78AReg) allows: every other operand of
// that value would have to be in AX too, and two of them at once cannot be.
// Leave the copy for the allocator's hints to remove.
bool RL78RegisterInfo::shouldCoalesce(
    MachineInstr *MI, const TargetRegisterClass *SrcRC, unsigned SubReg,
    const TargetRegisterClass *DstRC, unsigned DstSubReg,
    const TargetRegisterClass *NewRC, LiveIntervals &LIS) const {
  if (NewRC->getNumRegs() != 1)
    return true;
  // With -rl78-acc-coalesce, a whole value copied into AX/A may be kept
  // there; the allocator splits it out again where it cannot stay. Through a
  // subregister the join would pin the whole pair to AX (`%p.sub_hi = CLRB`
  // makes %p RL78AXRP).
  if (SrcRC->getNumRegs() == 1 && DstRC->getNumRegs() == 1)
    return true;
  if (SubReg || DstSubReg)
    return false;
  // Joining is free when nothing else needs the accumulator while either
  // value is live: no pinned use or clobber of AX/A overlaps them. The value
  // can then simply stay in AX/A and the copies disappear.
  if (!RL78AccCoalesce) {
    MCRegister Acc = *NewRC->begin();
    const MachineRegisterInfo &MRI = MI->getMF()->getRegInfo();
    Register Dst = MI->getOperand(0).getReg(), Src = MI->getOperand(1).getReg();
    // A copy of the joined value (or the value it is a copy of) is the same
    // value and will be joined as well: no competition for the accumulator.
    auto SameValue = [&](Register R) {
      for (const MachineInstr &DI : MRI.def_instructions(R))
        if (DI.isCopy() && (DI.getOperand(1).getReg() == Dst ||
                            DI.getOperand(1).getReg() == Src))
          return true;
      for (Register J : {Dst, Src})
        for (const MachineInstr &DI : MRI.def_instructions(J))
          if (DI.isCopy() && DI.getOperand(1).getReg() == R)
            return true;
      return false;
    };
    for (Register R : {Dst, Src}) {
      const LiveInterval &LI = LIS.getInterval(R);
      for (MCRegUnit Unit : regunits(Acc))
        if (LIS.getRegUnit(Unit).overlaps(LI)) {
          LLVM_DEBUG(dbgs() << "RL78 no acc join: " << printReg(R, this)
                            << " overlaps a use of " << printReg(Acc, this)
                            << " in " << *MI);
          return false;
        }
      // Nor may another value that has to be in the accumulator be read or
      // written while this one is live.
      for (const LiveRange::Segment &Seg : LI) {
        for (SlotIndex I = Seg.start.getBaseIndex(); I < Seg.end;
             I = I.getNextIndex()) {
          const MachineInstr *UI = LIS.getInstructionFromIndex(I);
          if (!UI)
            continue;
          for (const MachineOperand &MO : UI->operands()) {
            if (!MO.isReg() || !MO.getReg().isVirtual() || MO.getReg() == Dst ||
                MO.getReg() == Src)
              continue;
            const TargetRegisterClass *RC = MRI.getRegClass(MO.getReg());
            if (RC->getNumRegs() == 1 && regsOverlap(*RC->begin(), Acc) &&
                !SameValue(MO.getReg())) {
              LLVM_DEBUG(dbgs() << "RL78 no acc join: " << printReg(R, this)
                                << " overlaps " << printReg(MO.getReg(), this)
                                << " at " << *UI);
              return false;
            }
          }
        }
      }
    }
  }
  // Nor when either value is read or written in part elsewhere: splitting
  // the pinned value around such accesses does not always succeed.
  const MachineRegisterInfo &MRI = MI->getMF()->getRegInfo();
  for (const MachineOperand &Op : MI->operands()) {
    if (!Op.isReg() || !Op.getReg().isVirtual())
      continue;
    for (const MachineOperand &MO : MRI.reg_nodbg_operands(Op.getReg()))
      if (MO.getSubReg())
        return false;
  }
  return true;
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
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
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
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp), RL78::RP2);
  }
}

void build16bitAccess(MachineBasicBlock &MBB, MachineFunction &MF,
                      MachineInstr &MI, const TargetFrameLowering *TFI,
                      MachineBasicBlock::iterator &II, DebugLoc &DL,
                      const TargetInstrInfo *TII, unsigned int FrameReg,
                      unsigned int Offset) {
  unsigned int opCode = MI.getOpcode();
  bool is8bit = (opCode == RL78::LOAD8_r_stack_slot) ||
                (opCode == RL78::STORE8_stack_slot_r);
  bool isLoad = ((opCode == RL78::LOAD8_r_stack_slot) ||
                 (opCode == RL78::LOAD16_rp_stack_slot));
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
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
        .addReg(RL78::RP0, RegState::Kill);
    if (!isLoad) {
      BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::RP0)
          .addReg(mainRegister, RegState::Kill);
    }
    buildWordBCAccess(MBB, MF, TFI, II, DL, TII, isLoad, false, FrameReg,
                      Offset, 2, false);
    BuildMI(MBB, II, DL, TII->get(RL78::COPY), mainRegister)
        .addReg(RL78::RP0, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp), RL78::RP0);
  } else if (mainRegister == RL78::RP4 ||
             (mainRegister == RL78::RP6 && FrameReg != RL78::RP6)) {
    // if mainRegister == DE/HL and we don't try to store HL to [HL+offset].
    // XCHW AX, DE/HL.
    // PUSH BC.
    // MOVW BC, FrameReg.
    // LOAD/STORE AX/A from/to Offset+2[BC].
    // POP BC.
    // XCHW AX, DE/HL.
    BuildMI(MBB, II, DL, TII->get(RL78::XCHW_AX_rp), RL78::RP0)
        .addReg(mainRegister, RegState::Define)
        .addReg(RL78::RP0, RegState::Kill)
        .addReg(mainRegister, RegState::Kill);
    buildWordBCAccess(MBB, MF, TFI, II, DL, TII, isLoad, is8bit, FrameReg,
                      Offset);
    BuildMI(MBB, II, DL, TII->get(RL78::XCHW_AX_rp), RL78::RP0)
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
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
        .addReg(RL78::RP4, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::R4)
        .addReg(RL78::R1, RegState::Kill);
    buildWordBCAccess(MBB, MF, TFI, II, DL, TII, isLoad, is8bit, FrameReg,
                      Offset, 2);
    BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::R0)
        .addReg(RL78::R1, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::R1)
        .addReg(RL78::R4, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp), RL78::RP4);
  } else {
    // PUSH AX.
    // if store COPY AX/A, mainRegister.
    // PUSH BC.
    // MOVW BC, FrameReg.
    // LOAD/STORE AX/A from/to Offset+4[BC].
    // POP BC.
    // if load COPY mainRegister, AX/A.
    // POP AX.
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
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
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp), RL78::RP0);
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
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
        .addReg(RL78::RP2, RegState::Kill);
    unsigned additionalAdj = 0;
    if (actualFrameReg == RL78::SPreg) {
      BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_sp), RL78::RP0)
          .addReg(actualFrameReg);
      additionalAdj = 2;
      // If we are using SP, account for the bc push.
    } else
      BuildMI(MBB, II, DL, TII->get(RL78::MOVW_AX_rp), RL78::RP0)
          .addReg(actualFrameReg);

    BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_AX), RL78::RP2)
        .addReg(RL78::RP0, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::LOAD16_rp_rpi), RL78::RP0)
        .addReg(RL78::RP2, RegState::Kill)
        .addImm(offset + additionalAdj);
    BuildMI(MBB, II, DL, TII->get(RL78::POP_rp), RL78::RP2);
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
  if ((MI.getOpcode() == RL78::LOAD8_r_stack_slot) ||
      (MI.getOpcode() == RL78::LOAD16_rp_stack_slot) ||
      (MI.getOpcode() == RL78::STORE8_stack_slot_r) ||
      (MI.getOpcode() == RL78::STORE16_stack_slot_rp)) {

    int offsetAdj = 0;
    if (FrameReg == RL78::RP4) {
      // It means we first need to retrieve the old SP.
      BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
          .addReg(RL78::RP6, RegState::Kill);
      offsetAdj += 2;

      if (MI.getOpcode() != RL78::LOAD16_rp_stack_slot) {
        BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
            .addReg(RL78::RP0, RegState::Kill);
        offsetAdj += 2;
      }

      if (actualFrameReg != RL78::SPreg)
        offsetAdj = 0;

      int stackSize = MF.getFrameInfo().getStackSize();

      loadUnalignedSP(MBB, II, DL, TII, actualFrameReg,
                      stackSize - 2 + offsetAdj);

      BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_AX), RL78::RP6)
          .addReg(RL78::RP0, RegState::Kill);

      if (MI.getOpcode() != RL78::LOAD16_rp_stack_slot)
        BuildMI(MBB, II, DL, TII->get(RL78::POP_rp), RL78::RP0);

      FrameReg = RL78::RP6;
      BuildMI(MBB, std::next(II), DL, TII->get(RL78::POP_rp), RL78::RP6);
    }

    if (isUInt<8>(Offset + offsetAdj)) {
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
  } else if (MI.getOpcode() == RL78::STORE8_stack_slot_imm) {
    if (isUInt<8>(Offset)) {
      MI.getOperand(FIOperandNum).ChangeToRegister(FrameReg, false);
      MI.getOperand(FIOperandNum + 1).ChangeToImmediate(Offset);
      if (isUInt<8>(Offset + 4))
        MI.getOperand(FIOperandNum + 1).setTargetFlags(SPII::MO_OUTLINE_SP);
      else
        MI.getOperand(FIOperandNum + 1).setTargetFlags(SPII::MO_NO_OUTLINE_SP);
      // MI.getParent()->dump();
      return false;
    } else if (isUInt<16>(Offset - 2)) {
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::PUSH_rp))
          .addReg(RL78::RP2, RegState::Kill);

      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::MOVW_rp_sp), RL78::RP2)
          .addReg(RL78::SPreg);
      Offset += 2;

      // Store using word[BC].
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::STORE8_ri_imm))
          .addReg(RL78::RP2)
          .addImm(Offset)
          .add(MI.getOperand(2));
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::POP_rp), RL78::RP2);

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
