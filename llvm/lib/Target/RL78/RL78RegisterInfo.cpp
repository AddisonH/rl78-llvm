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

#include "RL78MachineFunctionInfo.h"
#include "RL78Subtarget.h"
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/MachineDominators.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineLoopInfo.h"
#include "llvm/CodeGen/VirtRegMap.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-reginfo"

static cl::opt<bool> RL78CopyHints(
    "rl78-copy-hints", cl::Hidden, cl::init(true),
    cl::desc("Hint the register of a single-register class that a value is "
             "copied to or from"));

static cl::opt<bool> RL78JoinFree(
    "rl78-join-free", cl::Hidden, cl::init(true),
    cl::desc("Join a copy into a single-register class when nothing else "
             "needs that register meanwhile"));

#define GET_REGINFO_TARGET_DESC
#include "RL78GenRegisterInfo.inc"

// OBS. Return address is saved on the stack (CFA-4) however:
// 1. we set RA = PCreg just like GCC so we don't need to make changes in GDB.
// 2. we emit a DW_CFA_offset: r37 at cfa-4 in the CIE.
RL78RegisterInfo::RL78RegisterInfo() : RL78GenRegisterInfo(RL78::PCreg) {}

bool RL78RegisterInfo::isSmallClass(const TargetRegisterClass *RC) const {
  switch (RC->getID()) {
  case RL78::RL78AXRPRegClassID:
  case RL78::RL78HLRegClassID:
  case RL78::RL78BCRPRegClassID:
  case RL78::RL78DERPRegClassID:
  case RL78::RL78AXBCRPRegClassID:
  case RL78::RL78ARegRegClassID:
  case RL78::RL78XRegRegClassID:
  case RL78::RL78BReg8RegClassID:
  case RL78::RL78CReg8RegClassID:
    return true;
  }
  return false;
}

// A value split away from the instruction that needs it in a particular
// register (A, AX, HL, B or C, ...) may live in any register (pair).
const TargetRegisterClass *
RL78RegisterInfo::getLargestLegalSuperClass(const TargetRegisterClass *RC,
                                            const MachineFunction &MF) const {
  if (RL78::RL78RPRegsRegClass.hasSubClassEq(RC))
    return &RL78::RL78RPRegsRegClass;
  if (RL78::RL78RegRegClass.hasSubClassEq(RC))
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

// Joining a copy narrows the joined value to the class both ends allow. When
// that is one of the small classes (A, AX, HL, B or C, ...) the whole value
// would have to stay in those registers, and whatever else needs them while
// it lives has nowhere to go: the allocator can run out of registers. Keep a
// constrained value as short as RL78SplitConstrainedValues made it; the copy
// stays, with the allocator's hints to make it a no-op where the register is
// free. (Joining where it is provably free is a later optimisation.)
bool RL78RegisterInfo::getRegAllocationHints(
    Register VirtReg, ArrayRef<MCPhysReg> Order,
    SmallVectorImpl<MCPhysReg> &Hints, const MachineFunction &MF,
    const VirtRegMap *VRM, const LiveRegMatrix *Matrix) const {
  const MachineRegisterInfo &MRI = MF.getRegInfo();
  // The generic hints know the physical registers this value is copied to or
  // from, and virtual ones once they are assigned. A value that is copied
  // into the operand of an instruction that takes one register only (or
  // comes out of one) will meet that register for certain: say so before it
  // is assigned. There is no move between two of BC, DE and HL, nor between
  // two of X, C, B ..., so those go first; anything moves to and from AX
  // and A in one byte, and they are the registers everything else wants.
  SmallVector<MCPhysReg, 4> Fixed, Accumulator;
  if (RL78CopyHints && VirtReg.isVirtual()) {
    const TargetRegisterClass *RC = MRI.getRegClass(VirtReg);
    auto Add = [&](MCPhysReg Reg) {
      if (!Reg || !is_contained(Order, Reg) || MRI.isReserved(Reg))
        return;
      bool IsAcc = Reg == RL78::RP0 || Reg == RL78::R1;
      SmallVectorImpl<MCPhysReg> &List = IsAcc ? Accumulator : Fixed;
      if (!is_contained(List, Reg))
        List.push_back(Reg);
    };
    for (const MachineInstr &MI : MRI.reg_nodbg_instructions(VirtReg)) {
      if (!MI.isCopy())
        continue;
      const MachineOperand &Dst = MI.getOperand(0);
      const MachineOperand &Src = MI.getOperand(1);
      bool IsDef = Dst.getReg() == VirtReg;
      const MachineOperand &Mine = IsDef ? Dst : Src;
      const MachineOperand &Other = IsDef ? Src : Dst;
      if (!Other.getReg().isVirtual() || Other.getReg() == VirtReg)
        continue;
      if (VRM && VRM->hasPhys(Other.getReg()))
        continue;
      const TargetRegisterClass *OtherRC = MRI.getRegClass(Other.getReg());
      if (OtherRC->getNumRegs() != 1)
        continue;
      MCPhysReg Reg = *OtherRC->begin();
      // The register of this value that holds the other one.
      if (Other.getSubReg())
        Reg = getSubReg(Reg, Other.getSubReg());
      if (Reg && Mine.getSubReg())
        Reg = getMatchingSuperReg(Reg, Mine.getSubReg(), RC);
      Add(Reg);
    }
  }
  Hints.append(Fixed.begin(), Fixed.end());
  bool Hard = TargetRegisterInfo::getRegAllocationHints(VirtReg, Order, Hints,
                                                        MF, VRM, Matrix);
  for (MCPhysReg Reg : Accumulator)
    if (!is_contained(Hints, Reg))
      Hints.push_back(Reg);
  return Hard;
}

// Whether nothing else needs \p Reg while \p A or \p B is live: no use or
// definition of the physical register, no call that clobbers it, and no
// other value of a small class that includes it.
static bool isFreeAcross(MCRegister Reg, const LiveInterval &A,
                         const LiveInterval &B, LiveIntervals &LIS,
                         const MachineRegisterInfo &MRI,
                         const RL78RegisterInfo &TRI) {
  auto Overlaps = [&](const LiveRange &LR) {
    return A.overlaps(LR) || B.overlaps(LR);
  };
  for (MCRegUnit Unit : TRI.regunits(Reg))
    if (Overlaps(LIS.getRegUnit(Unit)))
      return false;
  for (const LiveInterval *LI : {&A, &B}) {
    BitVector Usable;
    if (LIS.checkRegMaskInterference(*LI, Usable) && !Usable.test(Reg))
      return false;
  }
  for (unsigned I = 0, E = MRI.getNumVirtRegs(); I != E; ++I) {
    Register VReg = Register::index2VirtReg(I);
    if (VReg == A.reg() || VReg == B.reg() || !LIS.hasInterval(VReg))
      continue;
    const TargetRegisterClass *RC = MRI.getRegClass(VReg);
    if (!TRI.isSmallClass(RC) ||
        none_of(*RC, [&](MCPhysReg R) { return TRI.regsOverlap(R, Reg); }))
      continue;
    if (Overlaps(LIS.getInterval(VReg)))
      return false;
  }
  return true;
}

bool RL78RegisterInfo::shouldCoalesce(
    MachineInstr *MI, const TargetRegisterClass *SrcRC, unsigned SubReg,
    const TargetRegisterClass *DstRC, unsigned DstSubReg,
    const TargetRegisterClass *NewRC, LiveIntervals &LIS) const {
  if (!isSmallClass(NewRC))
    return true;
  if (SubReg || DstSubReg)
    return false;
  // The copy two-address lowering makes for a tied operand joins two
  // constrained values next to one instruction.
  if (isSmallClass(SrcRC) && isSmallClass(DstRC))
    return true;
  // A value may stay in the one register an instruction needs it in for as
  // long as nothing else needs that register: every other need shows as a
  // value of a small class or as the physical register, so the joined value
  // can always be assigned.
  if (!RL78JoinFree || NewRC->getNumRegs() != 1)
    return false;
  Register Dst = MI->getOperand(0).getReg();
  Register Src = MI->getOperand(1).getReg();
  if (!Dst.isVirtual() || !Src.isVirtual())
    return false;
  return isFreeAcross(*NewRC->begin(), LIS.getInterval(Src),
                      LIS.getInterval(Dst), LIS,
                      MI->getMF()->getRegInfo(), *this);
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
  // CS is zero except around a far indirect call or jump.
  Reserved.set(RL78::CS);
  // The program status word always has a value; PUSH PSW and POP PSW save
  // the interrupt enable flag around a sequence that must not be interrupted.
  Reserved.set(RL78::PSW);

  return Reserved;
}

/// Returns a TargetRegisterClass used for pointer values.
/// If a target supports multiple different pointer register classes,
/// kind specifies which one is indicated.
const TargetRegisterClass *
RL78RegisterInfo::getPointerRegClass(unsigned Kind) const {
  return &RL78::RL78RPRegsRegClass;
}

// The flags of a read that saves \p Reg around a use of it as a temporary:
// an undef use when the register has no value that \p I or a later
// instruction reads.
static auto saveState(MachineBasicBlock &MBB, MachineBasicBlock::iterator I,
                      MCRegister Reg) {
  const auto *TII = static_cast<const RL78InstrInfo *>(
      MBB.getParent()->getSubtarget().getInstrInfo());
  return getUndefRegState(!TII->isLiveBefore(MBB, I, Reg));
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
        .addReg(RL78::RP2, saveState(MBB, II, RL78::RP2));
    if (FrameReg == RL78::SPreg) {
      offset = offset + 2;
    }
  }

  BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::RP2).addReg(FrameReg);

  if (isLoad) {
    BuildMI(MBB, II, DL,
            TII->get(is8bit ? RL78::MOV_A_mBCw : RL78::MOVW_AX_mBCw),
            is8bit ? RL78::R1 : RL78::RP0)
        .addReg(RL78::RP2)
        .addImm(offset);
  } else {
    BuildMI(MBB, II, DL,
            TII->get(is8bit ? RL78::MOV_mBCw_A : RL78::MOVW_mBCw_AX))
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
    BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
        .addReg(RL78::RP0, saveState(MBB, II, RL78::RP0));
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
        .addReg(RL78::RP4, saveState(MBB, II, RL78::RP4));
    BuildMI(MBB, II, DL, TII->get(RL78::COPY), RL78::R4)
        .addReg(RL78::R1, saveState(MBB, II, RL78::R1));
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
        .addReg(RL78::RP0, saveState(MBB, II, RL78::RP0));
    if (!isLoad) {
      BuildMI(MBB, II, DL, TII->get(RL78::COPY), is8bit ? RL78::R1 : RL78::RP0)
          .addReg(mainRegister, getKillRegState(MI.getOperand(2).isKill()));
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
  static_cast<const RL78InstrInfo *>(TII)->setExchangeFlags(MBB);
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
        .addReg(RL78::RP2, saveState(MBB, II, RL78::RP2));
    unsigned additionalAdj = 0;
    if (actualFrameReg == RL78::SPreg) {
      BuildMI(MBB, II, DL, TII->get(RL78::MOVW_AX_SP), RL78::RP0)
          .addReg(actualFrameReg);
      additionalAdj = 2;
      // If we are using SP, account for the bc push.
    } else
      BuildMI(MBB, II, DL, TII->get(RL78::MOVW_AX_rp), RL78::RP0)
          .addReg(actualFrameReg);

    BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_AX), RL78::RP2)
        .addReg(RL78::RP0, RegState::Kill);
    BuildMI(MBB, II, DL, TII->get(RL78::MOVW_AX_mBCw), RL78::RP0)
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

  // The loads of arguments are spill-slot loads from here on.
  if (MI.getOpcode() == RL78::LOAD8_r_arg_slot)
    MI.setDesc(TII->get(RL78::LOAD8_r_stack_slot));
  else if (MI.getOpcode() == RL78::LOAD16_rp_arg_slot)
    MI.setDesc(TII->get(RL78::LOAD16_rp_stack_slot));

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
      BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
          .addReg(RL78::RP6, saveState(MBB, II, RL78::RP6));
      offsetAdj += 2;

      if (!IsWordLoad) {
        BuildMI(MBB, II, DL, TII->get(RL78::PUSH_rp))
            .addReg(RL78::RP0, saveState(MBB, II, RL78::RP0));
        offsetAdj += 2;
      }

      if (actualFrameReg != RL78::SPreg)
        offsetAdj = 0;

      int stackSize = MF.getFrameInfo().getStackSize();

      loadUnalignedSP(MBB, II, DL, TII, actualFrameReg,
                      stackSize - 2 + offsetAdj);

      BuildMI(MBB, II, DL, TII->get(RL78::MOVW_rp_AX), RL78::RP6)
          .addReg(RL78::RP0, RegState::Kill);

      if (!IsWordLoad)
        BuildMI(MBB, II, DL, TII->get(RL78::POP_rp), RL78::RP0);

      FrameReg = RL78::RP6;
      BuildMI(MBB, std::next(II), DL, TII->get(RL78::POP_rp), RL78::RP6);
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
  } else if (MI.getOpcode() == RL78::MOV_mSPi_i8) {
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
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::PUSH_rp))
          .addReg(RL78::RP2, saveState(MBB, II, RL78::RP2));

      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::MOVW_rp_SP), RL78::RP2)
          .addReg(RL78::SPreg);
      Offset += 2;

      // Store using word[BC].
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::MOV_mBCw_i8))
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
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::MOVW_AX_SP), RL78::RP0)
          .addReg(RL78::SPreg);

    if (Offset)
      BuildMI(*MI.getParent(), II, DL, TII->get(RL78::ADDW_AX_i16), RL78::RP0)
          .addReg(RL78::RP0)
          .addImm(Offset);
    MI.eraseFromParent();
    return true;
  }
}

Register RL78RegisterInfo::getFrameRegister(const MachineFunction &MF) const {
  return RL78::SPreg;
}

static cl::opt<unsigned>
    SplitLoopBytes("rl78-split-loop-bytes", cl::Hidden, cl::init(12),
                   cl::desc("Split by region the values of an innermost "
                            "loop whose virtual registers are at most this "
                            "many bytes together (0: none)"));

bool RL78RegisterInfo::shouldRegionSplitForVirtReg(
    const MachineFunction &MF, const LiveInterval &VirtReg) const {
  // A value split between two of BC, DE and HL is copied with PUSH and POP,
  // or through AX, where the pieces meet: two instructions where the
  // allocator counts one, and with three pairs the pieces rarely get the
  // same one. It pays where the split is around a small loop that then runs
  // in registers: an innermost loop with few values (all its virtual
  // registers are counted, the short-lived ones too, so the limit is twice
  // what BC, DE and HL hold). The copies are bytes either way, so not in a
  // function optimized for size.
  const auto *FI = MF.getInfo<RL78MachineFunctionInfo>();
  if (!FI->RegionSplitCandidates) {
    FI->RegionSplitCandidates.emplace();
    if (SplitLoopBytes && !MF.getFunction().hasOptSize()) {
      const MachineRegisterInfo &MRI = MF.getRegInfo();
      MachineDominatorTree MDT(const_cast<MachineFunction &>(MF));
      MachineLoopInfo MLI(MDT);
      for (const MachineLoop *L : MLI.getLoopsInPreorder()) {
        if (!L->isInnermost())
          continue;
        SmallDenseSet<Register, 8> Regs;
        unsigned Bytes = 0;
        for (const MachineBasicBlock *MBB : L->blocks())
          for (const MachineInstr &MI : *MBB) {
            if (MI.isDebugInstr())
              continue;
            for (const MachineOperand &MO : MI.operands())
              if (MO.isReg() && MO.getReg().isVirtual() &&
                  Regs.insert(MO.getReg()).second)
                Bytes += getRegSizeInBits(*MRI.getRegClass(MO.getReg())) / 8;
          }
        if (Bytes <= SplitLoopBytes)
          FI->RegionSplitCandidates->insert(Regs.begin(), Regs.end());
      }
    }
  }
  return FI->RegionSplitCandidates->contains(VirtReg.reg());
}
