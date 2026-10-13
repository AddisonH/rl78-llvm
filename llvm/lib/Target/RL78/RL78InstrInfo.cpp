//===-- RL78InstrInfo.cpp - RL78 Instruction Information ----------------===//
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

#include "RL78Subtarget.h"
#include "llvm/CodeGen/LiveRegUnits.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define GET_INSTRINFO_CTOR_DTOR
#include "RL78GenInstrInfo.inc"

#define DEBUG_TYPE "InstrInfo"

// Pin the vtable to this file.
void RL78InstrInfo::anchor() {}

RL78InstrInfo::RL78InstrInfo(RL78Subtarget &ST)
    : RL78GenInstrInfo(ST, RI, RL78::ADJCALLSTACKDOWN, RL78::ADJCALLSTACKUP),
      RI(),
      Subtarget(ST) {}

/// isLoadFromStackSlot - If the specified machine instruction is a direct
/// load from a stack slot, return the virtual or physical register number of
/// the destination along with the FrameIndex of the loaded stack slot.  If
/// not, return 0.  This predicate must return 0 if the instruction has
/// any side effects other than loading from the stack slot.
Register RL78InstrInfo::isLoadFromStackSlot(const MachineInstr &MI,
                                            int &FrameIndex) const {
  // MI.dump();
  if ((MI.getOpcode() == RL78::LOAD8_r_stack_slot) ||
      (MI.getOpcode() == RL78::LOAD16_rp_stack_slot) ||
      (MI.getOpcode() == RL78::LOAD8_r_arg_slot) ||
      (MI.getOpcode() == RL78::LOAD16_rp_arg_slot) ||
      (MI.getOpcode() == RL78::MOV_A_mSPi) ||
      (MI.getOpcode() == RL78::MOVW_AX_mSPi)) {
    if (MI.getOperand(1).isFI() && MI.getOperand(2).isImm() &&
        MI.getOperand(2).getImm() == 0) {
      FrameIndex = MI.getOperand(1).getIndex();
      return MI.getOperand(0).getReg();
    }
  }
  return 0;
}

/// isStoreToStackSlot - If the specified machine instruction is a direct
/// store to a stack slot, return the virtual or physical register number of
/// the source reg along with the FrameIndex of the loaded stack slot.  If
/// not, return 0.  This predicate must return 0 if the instruction has
/// any side effects other than storing to the stack slot.
Register RL78InstrInfo::isStoreToStackSlot(const MachineInstr &MI,
                                           int &FrameIndex) const {
  if ((MI.getOpcode() == RL78::STORE8_stack_slot_r) ||
      (MI.getOpcode() == RL78::STORE16_stack_slot_rp) ||
      (MI.getOpcode() == RL78::MOV_mSPi_A) ||
      (MI.getOpcode() == RL78::MOVW_mSPi_AX)) {
    if (MI.getOperand(0).isFI() && MI.getOperand(1).isImm() &&
        MI.getOperand(1).getImm() == 0) {
      FrameIndex = MI.getOperand(0).getIndex();
      return MI.getOperand(2).getReg();
    }
  }
  return 0;
}

void RL78InstrInfo::storeRegToStackSlot(MachineBasicBlock &MBB,
                                        MachineBasicBlock::iterator I,
                                        Register SrcReg, bool isKill, int FI,
                                        const TargetRegisterClass *RC,
                                        Register VReg,
                                        MachineInstr::MIFlag Flags) const {
  DebugLoc DL;
  // dbgs() << "storeRegToStackSlot\n";
  if (I != MBB.end())
    DL = I->getDebugLoc();
  MachineFunction &MF = *MBB.getParent();
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  MachineMemOperand *MMO = MF.getMachineMemOperand(
      MachinePointerInfo::getFixedStack(MF, FI), MachineMemOperand::MOStore,
      MFI.getObjectSize(FI), MFI.getObjectAlign(FI));
  if ((RI.getRegSizeInBits(*RC) == 8)) {
    BuildMI(MBB, I, DL, get(RL78::STORE8_stack_slot_r))
        .addFrameIndex(FI)
        .addImm(0)
        .addReg(SrcReg, getKillRegState(isKill))
        .addMemOperand(MMO)
        .setMIFlag(Flags);
  } else {
    BuildMI(MBB, I, DL, get(RL78::STORE16_stack_slot_rp))
        .addFrameIndex(FI)
        .addImm(0)
        .addReg(SrcReg, getKillRegState(isKill))
        .addMemOperand(MMO)
        .setMIFlag(Flags);
  }
  // MBB.dump();
}

void RL78InstrInfo::loadRegFromStackSlot(MachineBasicBlock &MBB,
                                         MachineBasicBlock::iterator I,
                                         Register DestReg, int FI,
                                         const TargetRegisterClass *RC,
                                         Register VReg, unsigned SubReg,
                                         MachineInstr::MIFlag Flags) const {
  assert(SubReg == 0 && "RL78 does not reload into a subregister");
  DebugLoc DL;
  if (I != MBB.end())
    DL = I->getDebugLoc();
  // dbgs() << "loadRegFromStackSlot\n";
  MachineFunction &MF = *MBB.getParent();
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  MachineMemOperand *MMO = MF.getMachineMemOperand(
      MachinePointerInfo::getFixedStack(MF, FI), MachineMemOperand::MOLoad,
      MFI.getObjectSize(FI), MFI.getObjectAlign(FI));
  if (RI.getRegSizeInBits(*RC) == 8) {
    BuildMI(MBB, I, DL, get(RL78::LOAD8_r_stack_slot), DestReg)
        .addFrameIndex(FI)
        .addImm(0)
        .addMemOperand(MMO)
        .setMIFlag(Flags);
  } else {
    BuildMI(MBB, I, DL, get(RL78::LOAD16_rp_stack_slot), DestReg)
        .addFrameIndex(FI)
        .addImm(0)
        .addMemOperand(MMO)
        .setMIFlag(Flags);
    // We can't do this here becuase it's done during reg alloc.
    // BuildMI(MBB, I, DL, get(RL78::LOAD16_rp_stack_slot),
    // RL78::RP0).addFrameIndex(FI).addImm(0); BuildMI(MBB, I, DL,
    // get(RL78::COPY)).addReg(DestReg).addReg(RL78::RP0, RegState::Kill);
  }
  // MBB.dump();
}

static void BuildUnrolledShiftStep(const RL78InstrInfo *II,
                            llvm::MachineBasicBlock *BB, llvm::MachineInstr &MI,
                            llvm::DebugLoc &DL, unsigned int opcode,
                            const llvm::Register &Rd,
                            unsigned CounterShiftAmount, unsigned RdOpAmount,
                            unsigned OpSize, unsigned OpInstrCount,
                            MachineInstrBuilder &FirstInstruction,
                            MachineInstrBuilder &LastInstruction) {

  unsigned JumpSize = OpSize * RdOpAmount;
  if (RdOpAmount == 1) {
    FirstInstruction = BuildMI(*BB, MI, DL, II->get(RL78::CMP0_r))
                           .addReg(RL78::R3, RegState::Kill);
    if (OpInstrCount > 1)
      BuildMI(*BB, MI, DL, II->get(RL78::Bcc_over))
          .addImm(JumpSize)
          .addImm(RL78CC::RL78CC_Z);
    else
      BuildMI(*BB, MI, DL, II->get(RL78::SKcc)).addImm(RL78CC::RL78CC_Z);
  } else {
    FirstInstruction = BuildMI(*BB, MI, DL, II->get(RL78::SHL_r_n), RL78::R3)
                           .addReg(RL78::R3, RegState::Kill)
                           .addImm(CounterShiftAmount);
    if (OpInstrCount > 1 || JumpSize > 0)
      BuildMI(*BB, MI, DL, II->get(RL78::Bcc_over))
          .addImm(JumpSize)
          .addImm(RL78CC::RL78CC_NC);
    else
      BuildMI(*BB, MI, DL, II->get(RL78::SKcc))
          .addImm(RL78CC::RL78CC_NC);
  }

  switch (opcode) {
  case RL78::ROTL16_rp_rp:
    for (unsigned i = 0; i < RdOpAmount; i++) {
      BuildMI(*BB, MI, DL, II->get(RL78::MOV1_CY_A_b)).addReg(RL78::R1).addImm(7);
      LastInstruction =
          BuildMI(*BB, MI, DL, II->get(RL78::ROLWC_rp_1), RL78::RP0)
              .addReg(RL78::RP0, RegState::Kill);
    }
    break;

  case RL78::ROTR16_rp_rp:
    for (unsigned i = 0; i < RdOpAmount; i++) {
      BuildMI(*BB, MI, DL, II->get(RL78::SHRW_AX_n), RL78::RP0)
          .addReg(RL78::RP0, RegState::Kill)
          .addImm(1);
      LastInstruction = BuildMI(*BB, MI, DL, II->get(RL78::MOV1_A_b), RL78::R1)
                            .addReg(RL78::R1)
                            .addImm(7);
    }
    break;
  case RL78::ROR_A_1:
  case RL78::ROL_A_1:
    for (unsigned i = 0; i < RdOpAmount; i++) {
      LastInstruction =
          BuildMI(*BB, MI, DL, II->get(opcode), Rd).addReg(Rd, RegState::Kill);
    }
    break;

  case RL78::SHLW_rp_n:
    if (RdOpAmount == 1)
      LastInstruction = BuildMI(*BB, MI, DL, II->get(RL78::ADDW_AX_rp), Rd)
                            .addReg(Rd)
                            .addReg(Rd, RegState::Kill);
    else
      LastInstruction = BuildMI(*BB, MI, DL, II->get(opcode), Rd)
                            .addReg(Rd, RegState::Kill)
                            .addImm(RdOpAmount);
    break;
  default:
    LastInstruction = BuildMI(*BB, MI, DL, II->get(opcode), Rd)
                          .addReg(Rd, RegState::Kill)
                          .addImm(RdOpAmount);
    break;
  }
}

static bool BuildADDE_SUBBE_rp_rp(const RL78InstrInfo *II,
                                  llvm::MachineBasicBlock *BB,
                                  llvm::MachineInstr &MI, llvm::DebugLoc &DL,
                                  unsigned int carryOpcode,
                                  unsigned int opcode) {
  MachineInstrBuilder FirstInstruction, LastInstruction;

  if (!MI.getOperand(0).isReg() || MI.getOperand(0).getReg() != RL78::RP0 ||
      !MI.getOperand(1).isReg() ||
      MI.getOperand(0).getReg() != MI.getOperand(1).getReg() ||
      !MI.getOperand(2).isReg())
    return false;

  FirstInstruction = BuildMI(*BB, MI, DL, II->get(RL78::SKcc))
                         .addImm(RL78CC::RL78CC_NC);
  BuildMI(*BB, MI, DL, II->get(carryOpcode), RL78::RP0)
      .addReg(RL78::RP0, RegState::Kill);

  LastInstruction = BuildMI(*BB, MI, DL, II->get(opcode), RL78::RP0)
                        .addReg(RL78::RP0, RegState::Kill)
                        .add(MI.getOperand(2));
  // The displacement of [HL+byte].
  if (MI.getNumExplicitOperands() == 4)
    LastInstruction.add(MI.getOperand(3));
  LastInstruction.cloneMemRefs(MI);
  finalizeBundle(*BB, FirstInstruction->getIterator(),
                 std::next(LastInstruction->getIterator()));
  MI.eraseFromParent();
  return true;
}

static bool Build_MUL16_rp_rp_S2(const RL78InstrInfo *II,
                                 llvm::MachineBasicBlock *BB,
                                 llvm::MachineInstr &MI, llvm::DebugLoc &DL) {
#define MDUC 0x00E8
#define MDAL 0xFFFF0
#define MDAH 0xFFFF2
#define MDBL 0xFFFF6
  //  push  psw
  //  di
  //  clrb  !%lo16(MDUC)
  //  movw  MDAL, ax
  //  movw  ax, bc
  //  movw  MDAH, ax
  //  nop
  //  movw  ax, MDBL
  //  pop  psw ;
  //  MDUC -> F00E8, MDAL -> FFFF0, MDAH -> FFFF2, MDBL -> FFFF6
    MachineInstrBuilder FirstInstruction, LastInstruction;

  // PSW register contents are saved to the stack.
  FirstInstruction =
      BuildMI(*BB, MI, DL, II->get(RL78::PUSH_PSW))
          .addReg(RL78::PSW)
          // The flags are saved with it, whether they have a value or not.
          .addReg(RL78::CCreg,
                  RegState::Implicit |
                      getUndefRegState(!II->isLiveBefore(*BB, MI, RL78::CCreg)));

  // Maskable interrupt acknowledgment by vectored interrupt is disabled (with
  // the interrupt enable flag (IE) cleared (0)).
  BuildMI(*BB, MI, DL, II->get(RL78::DI));

  // 0 is transferred to the MDUC address.
  BuildMI(*BB, MI, DL, II->get(RL78::CLRB_abs16)).addImm(MDUC);

  // AX register contents is transferred to the MDAL address.
  BuildMI(*BB, MI, DL, II->get(RL78::MOVW_sfrp_AX))
      .addImm(MDAL)
      .addReg(RL78::RP0, RegState::Kill);

  // Op2 register contents is transferred to the AX register.
  if (MI.getOperand(2).getReg() != RL78::RP0)
    BuildMI(*BB, MI, DL, II->get(RL78::MOVW_AX_rp), RL78::RP0)
        .addReg(MI.getOperand(2).getReg(), RegState::Kill);

  // AX register contents is transferred to the MDAH address.
  BuildMI(*BB, MI, DL, II->get(RL78::MOVW_sfrp_AX))
      .addImm(MDAH)
      .addReg(RL78::RP0, RegState::Kill);

  // Only the time is consumed without processing.
  BuildMI(*BB, MI, DL, II->get(RL78::NOP));

  // MDBL address contents is transferred to the AX register.
  BuildMI(*BB, MI, DL, II->get(RL78::MOVW_AX_sfrp), RL78::RP0).addImm(MDBL);

  // Each flag is replaced with stack data.
  LastInstruction = BuildMI(*BB, MI, DL, II->get(RL78::POP_PSW), RL78::PSW)
                        .addReg(RL78::CCreg, RegState::ImplicitDefine);

  finalizeBundle(*BB, FirstInstruction->getIterator(),
                 std::next(LastInstruction->getIterator()));
  MI.eraseFromParent();

  return true;
}

// 16 x 16 -> 16 with three MULU, on AX and BC with DE as well:
//  xch a, c; movw de, ax; xch a, b; mulu x; xchw ax, bc; mulu x;
//  xchw ax, de; mulu x; add a, e; add a, c
static bool Build_MUL16_rp_rp_S1(const RL78InstrInfo *II,
                                 llvm::MachineBasicBlock *BB,
                                 llvm::MachineInstr &MI, llvm::DebugLoc &DL) {
  auto XchA = [&](MCRegister Reg) {
    BuildMI(*BB, MI, DL, II->get(RL78::XCH_A_r), RL78::R1)
        .addReg(Reg, RegState::Define)
        .addReg(RL78::R1, RegState::Kill)
        .addReg(Reg, RegState::Kill);
  };
  auto XchwAX = [&](MCRegister Reg) {
    BuildMI(*BB, MI, DL, II->get(RL78::XCHW_AX_rp), RL78::RP0)
        .addReg(Reg, RegState::Define)
        .addReg(RL78::RP0, RegState::Kill)
        .addReg(Reg, RegState::Kill);
  };
  auto Mulu = [&] {
    BuildMI(*BB, MI, DL, II->get(RL78::MULU_X), RL78::RP0)
        .addReg(RL78::R1)
        .addReg(RL78::R0);
  };
  auto AddA = [&](MCRegister Reg) {
    BuildMI(*BB, MI, DL, II->get(RL78::ADD_A_r), RL78::R1)
        .addReg(RL78::R1, RegState::Kill)
        .addReg(Reg, RegState::Kill);
  };
  XchA(RL78::R2);
  BuildMI(*BB, MI, DL, II->get(RL78::MOVW_rp_AX), RL78::RP4)
      .addReg(RL78::RP0, RegState::Kill);
  XchA(RL78::R3);
  Mulu();
  XchwAX(RL78::RP2);
  Mulu();
  XchwAX(RL78::RP4);
  Mulu();
  AddA(RL78::R4);
  AddA(RL78::R2);
  MI.eraseFromParent();
  return true;
}

// ROL/ROR of A by a constant.
static bool BuildRotate8(const RL78InstrInfo *II, llvm::MachineBasicBlock *BB,
                         llvm::MachineInstr &MI, llvm::DebugLoc &DL) {
  unsigned Left = MI.getOperand(2).getImm() & 7;
  if (MI.getOpcode() == RL78::ROTR_r_imm)
    Left = (8 - Left) & 7;
  if (Left == 4) {
    // The nibbles change places: clrb x; shrw ax, 4; or a, x.
    BuildMI(*BB, MI, DL, II->get(RL78::CLRB_r), RL78::R0);
    BuildMI(*BB, MI, DL, II->get(RL78::SHRW_AX_n), RL78::RP0)
        .addReg(RL78::RP0, RegState::Kill)
        .addImm(4);
    BuildMI(*BB, MI, DL, II->get(RL78::OR_A_r), RL78::R1)
        .addReg(RL78::R1, RegState::Kill)
        .addReg(RL78::R0, RegState::Kill);
  } else {
    // Up to three places, in the shorter direction.
    unsigned Opcode = Left < 4 ? RL78::ROL_A_1 : RL78::ROR_A_1;
    for (unsigned I = 0, E = Left < 4 ? Left : 8 - Left; I != E; ++I)
      BuildMI(*BB, MI, DL, II->get(Opcode), RL78::R1)
          .addReg(RL78::R1, RegState::Kill);
  }
  MI.eraseFromParent();
  return true;
}

// Rotate of AX by a constant.
static bool BuildRotate16(const RL78InstrInfo *II, llvm::MachineBasicBlock *BB,
                          llvm::MachineInstr &MI, llvm::DebugLoc &DL) {
  unsigned Left = RL78InstrInfo::getRotate16Left(MI);
  if (RL78InstrInfo::rotate16UsesBC(MI)) {
    // movw bc, ax; shlw bc, n; shrw ax, 16 - n; addw ax, bc
    BuildMI(*BB, MI, DL, II->get(RL78::MOVW_rp_AX), RL78::RP2)
        .addReg(RL78::RP0);
    BuildMI(*BB, MI, DL, II->get(RL78::SHLW_rp_n), RL78::RP2)
        .addReg(RL78::RP2, RegState::Kill)
        .addImm(Left);
    BuildMI(*BB, MI, DL, II->get(RL78::SHRW_AX_n), RL78::RP0)
        .addReg(RL78::RP0, RegState::Kill)
        .addImm(16 - Left);
    BuildMI(*BB, MI, DL, II->get(RL78::ADDW_AX_rp), RL78::RP0)
        .addReg(RL78::RP0, RegState::Kill)
        .addReg(RL78::RP2, RegState::Kill);
    MI.eraseFromParent();
    return true;
  }
  // One place to the left or to the right, and the bytes exchanged for
  // eight.
  if (Left == 1 || Left == 9) {
    BuildMI(*BB, MI, DL, II->get(RL78::MOV1_CY_A_b)).addReg(RL78::R1).addImm(7);
    BuildMI(*BB, MI, DL, II->get(RL78::ROLWC_rp_1), RL78::RP0)
        .addReg(RL78::RP0, RegState::Kill);
  } else if (Left == 7 || Left == 15) {
    BuildMI(*BB, MI, DL, II->get(RL78::SHRW_AX_n), RL78::RP0)
        .addReg(RL78::RP0, RegState::Kill)
        .addImm(1);
    BuildMI(*BB, MI, DL, II->get(RL78::MOV1_A_b), RL78::R1)
        .addReg(RL78::R1, RegState::Kill)
        .addImm(7);
  }
  if (Left >= 7 && Left <= 9)
    BuildMI(*BB, MI, DL, II->get(RL78::XCH_A_X), RL78::R1)
        .addReg(RL78::R0, RegState::Define)
        .addReg(RL78::R1, RegState::Kill)
        .addReg(RL78::R0, RegState::Kill);
  MI.eraseFromParent();
  return true;
}

namespace {
// The 8-bit instructions a 16-bit operation on AX is made of.
struct WideOp {
  unsigned R, I8, MHL, MHLi, Abs16;
  bool Carry;
};
enum WideForm { WideRP, WideImm, WideMHLi, WideAbs16, NotWide };
} // namespace

static WideForm getWideOp(unsigned Opcode, WideOp &W) {
  switch (Opcode) {
#define RL78_WIDE(PSEUDO, OP, CARRY)                                           \
  case RL78::PSEUDO##_AX_rp:                                                   \
  case RL78::PSEUDO##_AX_i16:                                                  \
  case RL78::PSEUDO##_AX_mHLi:                                                 \
  case RL78::PSEUDO##_AX_abs16:                                                \
    W = {RL78::OP##_A_r, RL78::OP##_A_i8, RL78::OP##_A_mHL, RL78::OP##_A_mHLi, \
         RL78::OP##_A_abs16, CARRY};                                           \
    return Opcode == RL78::PSEUDO##_AX_rp     ? WideRP                         \
           : Opcode == RL78::PSEUDO##_AX_i16  ? WideImm                        \
           : Opcode == RL78::PSEUDO##_AX_mHLi ? WideMHLi                       \
                                              : WideAbs16;
    RL78_WIDE(AND16, AND, false)
    RL78_WIDE(OR16, OR, false)
    RL78_WIDE(XOR16, XOR, false)
    RL78_WIDE(ADDE, ADDC, true)
    RL78_WIDE(SUBE, SUBC, true)
#undef RL78_WIDE
  }
  return NotWide;
}

// AX = AX op source, as the 8-bit operation on A (the high byte) and, with
// XCH A, X around it, on the low byte: low byte first when a carry goes from
// one to the other.
bool RL78InstrInfo::expandWideOnAX(MachineInstr &MI) const {
  WideOp W;
  WideForm Form = getWideOp(MI.getOpcode(), W);
  if (Form == NotWide)
    return false;
  MachineBasicBlock &MBB = *MI.getParent();
  DebugLoc DL = MI.getDebugLoc();
  const TargetRegisterInfo &TRI = getRegisterInfo();
  assert(MI.getOperand(0).getReg() == RL78::RP0 && "not in AX");

  // ADDE/SUBE AX, rp or [HL+byte] when the carry out is unused and speed
  // matters: add the carry in with INCW/DECW under SKNC, then ADDW/SUBW.
  if (W.Carry && (Form == WideRP || Form == WideMHLi) &&
      MI.registerDefIsDead(RL78::CCreg, &TRI) &&
      MI.getMF()->getTarget().getOptLevel() == CodeGenOptLevel::Aggressive) {
    bool IsAdd = MI.getOpcode() == RL78::ADDE_AX_rp ||
                 MI.getOpcode() == RL78::ADDE_AX_mHLi;
    bool IsMem = Form == WideMHLi;
    return BuildADDE_SUBBE_rp_rp(
        this, &MBB, MI, DL, IsAdd ? RL78::INCW_rp : RL78::DECW_rp,
        IsAdd ? (IsMem ? RL78::ADDW_AX_mHLi : RL78::ADDW_AX_rp)
              : (IsMem ? RL78::SUBW_AX_mHLi : RL78::SUBW_AX_rp));
  }

  auto Xch = [&] {
    BuildMI(MBB, MI, DL, get(RL78::XCH_A_X))
        .addReg(RL78::R1, RegState::Define)
        .addReg(RL78::R0, RegState::Define)
        .addReg(RL78::R1)
        .addReg(RL78::R0);
  };
  auto OnA = [&](unsigned Opcode) {
    return BuildMI(MBB, MI, DL, get(Opcode), RL78::R1).addReg(RL78::R1);
  };
  // The operation on A with the low or the high byte of the source.
  auto Op = [&](bool Hi) {
    switch (Form) {
    case WideRP:
      OnA(W.R).addReg(TRI.getSubReg(MI.getOperand(2).getReg(),
                                    Hi ? RL78::sub_hi : RL78::sub_lo));
      break;
    case WideImm:
      OnA(W.I8).addImm((MI.getOperand(2).getImm() >> (Hi ? 8 : 0)) & 0xFF);
      break;
    case WideMHLi: {
      int64_t Disp = MI.getOperand(3).getImm() + Hi;
      if (Disp)
        OnA(W.MHLi).add(MI.getOperand(2)).addImm(Disp);
      else
        OnA(W.MHL).add(MI.getOperand(2));
      break;
    }
    case WideAbs16: {
      MachineOperand Addr = MI.getOperand(2);
      if (Addr.isImm())
        Addr.setImm(Addr.getImm() + Hi);
      else
        Addr.setOffset(Addr.getOffset() + Hi);
      OnA(W.Abs16).add(Addr);
      break;
    }
    case NotWide:
      break;
    }
  };

  if (W.Carry) {
    Xch();
    Op(false);
    Xch();
    Op(true);
  } else if (Form == WideImm) {
    // Per byte: AND with 0 clears it, AND with FFH and OR/XOR with 0 leave
    // it, OR with FFH sets it.
    bool IsAnd = W.I8 == RL78::AND_A_i8, IsOr = W.I8 == RL78::OR_A_i8;
    for (bool Hi : {false, true}) {
      unsigned Byte = (MI.getOperand(2).getImm() >> (Hi ? 8 : 0)) & 0xFF;
      MCRegister Reg = Hi ? RL78::R1 : RL78::R0;
      if (IsAnd && Byte == 0x00) {
        BuildMI(MBB, MI, DL, get(RL78::CLRB_r), Reg);
      } else if (IsOr && Byte == 0xFF) {
        BuildMI(MBB, MI, DL, get(RL78::MOV_r_i8), Reg).addImm(0xFF);
      } else if (Byte != (IsAnd ? 0xFF : 0x00)) {
        if (!Hi)
          Xch();
        Op(Hi);
        if (!Hi)
          Xch();
      }
    }
  } else {
    Op(true);
    Xch();
    Op(false);
    Xch();
  }
  MI.eraseFromParent();
  return true;
}

static bool isExchange(const MachineInstr &MI) {
  return MI.getOpcode() == RL78::XCH_A_X || MI.getOpcode() == RL78::XCH_A_r ||
         MI.getOpcode() == RL78::XCHW_AX_rp;
}

void RL78InstrInfo::setExchangeFlags(MachineBasicBlock &MBB,
                                     const MachineInstr *Ignore) const {
  const MachineRegisterInfo &MRI = MBB.getParent()->getRegInfo();
  auto Skip = [&](const MachineInstr &MI) {
    return &MI == Ignore || MI.isDebugOrPseudoInstr();
  };

  // Backwards: the half of an exchange whose result nothing reads, and the
  // kill flags, which the code that builds exchanges and saves does not know.
  LiveRegUnits Live(getRegisterInfo());
  Live.addLiveOuts(MBB);
  for (MachineInstr &MI : reverse(MBB)) {
    if (Skip(MI))
      continue;
    if (isExchange(MI)) {
      // Operands: the two definitions, then the two uses tied to them. Each
      // definition takes the value of the other use.
      for (unsigned I : {0u, 1u}) {
        MachineOperand &Def = MI.getOperand(I);
        bool Unused = Live.available(Def.getReg());
        Def.setIsDead(Unused);
        MI.getOperand(3 - I).setIsUndef(Unused);
      }
    }
    LiveRegUnits After = Live;
    for (const MachineOperand &MO : MI.all_defs())
      if (MO.getReg().isPhysical())
        After.removeReg(MO.getReg());
    for (MachineOperand &MO : MI.all_uses())
      if (MO.getReg().isPhysical() && !MRI.isReserved(MO.getReg()))
        MO.setIsKill(MO.readsReg() && After.available(MO.getReg()));
    Live.stepBackward(MI);
  }

  // Forwards: an exchange with a register that has no value at all, and a
  // push of one (a save around its use as a temporary, or two bytes of
  // stack).
  LiveRegUnits Defined(getRegisterInfo());
  Defined.addLiveIns(MBB);
  for (MachineInstr &MI : MBB) {
    if (Skip(MI))
      continue;
    if (isExchange(MI) || MI.getOpcode() == RL78::PUSH_rp)
      for (MachineOperand &Use : MI.explicit_uses())
        if (!Use.isUndef() && Defined.available(Use.getReg())) {
          Use.setIsUndef();
          Use.setIsKill(false);
        }
    for (const MachineOperand &MO : MI.operands()) {
      if (MO.isRegMask())
        Defined.removeRegsNotPreserved(MO.getRegMask());
      else if (MO.isReg() && MO.getReg().isPhysical() && MO.isUse() &&
               MO.isKill())
        Defined.removeReg(MO.getReg());
    }
    for (const MachineOperand &MO : MI.all_defs())
      if (MO.getReg().isPhysical() && !MO.isDead())
        Defined.addReg(MO.getReg());
  }
}

bool RL78InstrInfo::isLiveBefore(MachineBasicBlock &MBB,
                                 MachineBasicBlock::iterator I,
                                 MCRegister Reg) const {
  LiveRegUnits Live(getRegisterInfo());
  Live.addLiveOuts(MBB);
  for (MachineBasicBlock::iterator It = MBB.end(); It != I;)
    if (!(--It)->isDebugOrPseudoInstr())
      Live.stepBackward(*It);
  return !Live.available(Reg);
}

// The COPY that copyPhysReg is called to replace, if \p I is that: it is
// still in the block, and what is live is what is live after it.
static bool isCopyBeingLowered(MachineBasicBlock &MBB,
                               MachineBasicBlock::iterator I, Register DestReg,
                               Register SrcReg) {
  return I != MBB.end() && I->isCopy() &&
         I->getOperand(0).getReg() == DestReg &&
         I->getOperand(1).getReg() == SrcReg;
}

bool RL78InstrInfo::expandPostRAPseudo(MachineInstr &MI) const {
  MachineBasicBlock &MBB = *MI.getParent();
  if (!expandPseudo(MI))
    return false;
  setExchangeFlags(MBB);
  return true;
}

bool RL78InstrInfo::expandPseudo(MachineInstr &MI) const {
  MachineBasicBlock *BB = MI.getParent();
  DebugLoc DL = BB->findDebugLoc(MI);
  if (expandWideOnAX(MI))
    return true;
  //      shl b, 0x05
  //      sknc
  //      Op ax, 0x08
  //      shl b, 0x01
  //      sknc
  //      Op ax, 0x04
  //      shl b, 0x01
  //      sknc
  //      Op ax, 0x02
  //      cmp0 b
  //      skz
  //      Op ax, 0x01 or optimized variant
  bool Is8Bit = false;
  unsigned opcode;
  unsigned OpSize = 0;
  unsigned OpInstrCount = 1;
  switch (MI.getOpcode()) {
  case RL78::SHLW_rp_rp:
    opcode = RL78::SHLW_rp_n;
    break;
  case RL78::SHRW_rp_rp:
    opcode = RL78::SHRW_AX_n;
    break;
  case RL78::SARW_rp_rp:
    opcode = RL78::SARW_AX_n;
    break;
  case RL78::SHL_r_r:
    Is8Bit = true;
    opcode = RL78::SHL_r_n;
    break;
  case RL78::SHR_r_r:
    Is8Bit = true;
    opcode = RL78::SHR_A_n;
    break;
  case RL78::SAR_r_r:
    Is8Bit = true;
    opcode = RL78::SAR_A_n;
    break;
  case RL78::ROTL16_rp_rp:
    opcode = RL78::ROTL16_rp_rp;
    // 2 (MOV1_cy_r) + 2 (ROLWC_rp_1_cg)
    OpInstrCount = 2;
    OpSize = 4;
    break;
  case RL78::ROTR16_rp_rp:
    opcode = RL78::ROTR16_rp_rp;
    // 2 (SHRW_rp_i) + 2 (SHRW_rp_i)
    OpInstrCount = 2;
    OpSize = 4;
    break;
  case RL78::ROTL_rp_rp:
    Is8Bit = true;
    opcode = RL78::ROL_A_1;
    OpSize = 2;
    break;
  case RL78::ROTR_rp_rp:
    Is8Bit = true;
    opcode = RL78::ROR_A_1;
    OpSize = 2;
    break;
  case RL78::MUL16_rp_rp_S1_S2:
    return Subtarget.isUseMDA() ? Build_MUL16_rp_rp_S2(this, BB, MI, DL)
                                : Build_MUL16_rp_rp_S1(this, BB, MI, DL);
  case RL78::ROTL_r_imm:
  case RL78::ROTR_r_imm:
    return BuildRotate8(this, BB, MI, DL);
  case RL78::ROTL16_r_imm:
  case RL78::ROTR16_r_imm:
    return BuildRotate16(this, BB, MI, DL);
  case RL78::ROLW_AX_1:
    BuildMI(*BB, MI, DL, get(RL78::MOV1_CY_A_b)).addReg(RL78::R1).addImm(7);
    BuildMI(*BB, MI, DL, get(RL78::ROLWC_rp_1), RL78::RP0)
        .addReg(RL78::RP0, RegState::Kill);
    MI.eraseFromParent();
    return true;
  case RL78::RORWC_AX_1:
    // CY goes into bit 15 and bit 8 into CY, then that into bit 7.
    for (int Byte = 0; Byte != 2; ++Byte) {
      // Only the carry of a word without a value is wanted.
      RegState Undef = getUndefRegState(!Byte && MI.getOperand(1).isUndef());
      BuildMI(*BB, MI, DL, get(RL78::RORC_A_1), RL78::R1)
          .addReg(RL78::R1, RegState::Kill | Undef);
      BuildMI(*BB, MI, DL, get(RL78::XCH_A_X), RL78::R1)
          .addReg(RL78::R0, RegState::Define)
          .addReg(RL78::R1, RegState::Kill)
          .addReg(RL78::R0, RegState::Kill | Undef);
    }
    MI.eraseFromParent();
    return true;
  case RL78::ORZ_AX_rp: {
    Register RP = MI.getOperand(1).getReg();
    const TargetRegisterInfo &TRI = getRegisterInfo();
    for (MCRegister R : {MCRegister(RL78::R0), TRI.getSubReg(RP, RL78::sub_lo),
                         TRI.getSubReg(RP, RL78::sub_hi)})
      BuildMI(*BB, MI, DL, get(RL78::OR_A_r), RL78::R1)
          .addReg(RL78::R1)
          .addReg(R);
    MI.eraseFromParent();
    return true;
  }
  case RL78::MOV1_AX_15_CY:
    BuildMI(*BB, MI, DL, get(RL78::MOV1_A_b), RL78::R1)
        .addReg(RL78::R1)
        .addImm(7);
    MI.eraseFromParent();
    return true;
  case RL78::SHRB_AX_rp:
    BuildMI(*BB, MI, DL, get(RL78::MOV_r_A), RL78::R0)
        .addReg(RL78::R1, RegState::Kill);
    BuildMI(*BB, MI, DL, get(RL78::MOV_A_r), RL78::R1)
        .addReg(getRegisterInfo().getSubReg(MI.getOperand(2).getReg(),
                                            RL78::sub_lo));
    MI.eraseFromParent();
    return true;
  case RL78::SHLB_AX_rp:
    BuildMI(*BB, MI, DL, get(RL78::MOV_A_r), RL78::R1)
        .addReg(getRegisterInfo().getSubReg(MI.getOperand(2).getReg(),
                                            RL78::sub_hi));
    BuildMI(*BB, MI, DL, get(RL78::XCH_A_X), RL78::R1)
        .addReg(RL78::R0, RegState::Define)
        .addReg(RL78::R1, RegState::Kill)
        .addReg(RL78::R0, RegState::Kill);
    MI.eraseFromParent();
    return true;
  case RL78::RORW_AX_1:
    BuildMI(*BB, MI, DL, get(RL78::SHRW_AX_n), RL78::RP0)
        .addReg(RL78::RP0, RegState::Kill)
        .addImm(1);
    BuildMI(*BB, MI, DL, get(RL78::MOV1_A_b), RL78::R1)
        .addReg(RL78::R1)
        .addImm(7);
    MI.eraseFromParent();
    return true;
  default:
    return false;
    break;
  }

  Register Rd;
  MachineInstrBuilder FirstInstruction, LastInstruction, IgnoredInstruction;
  assert((MI.getOperand(2).isReg() && MI.getOperand(2).getReg() == RL78::R3) &&
         "Op2 != B");
  if (Is8Bit) {
    assert(
        (MI.getOperand(0).isReg() && MI.getOperand(0).getReg() == RL78::R1) &&
        "Op0 != A");
    Rd = RL78::R1;
    BuildUnrolledShiftStep(this, BB, MI, DL, opcode, Rd, 6, 4, OpSize,
                           OpInstrCount, FirstInstruction, IgnoredInstruction);
  } else {
    assert(
        (MI.getOperand(0).isReg() && MI.getOperand(0).getReg() == RL78::RP0) &&
        "Op0 != AX");

    Rd = RL78::RP0;
    BuildUnrolledShiftStep(this, BB, MI, DL, opcode, Rd, 5, 8, OpSize,
                           OpInstrCount, FirstInstruction, IgnoredInstruction);
    BuildUnrolledShiftStep(this, BB, MI, DL, opcode, Rd, 1, 4, OpSize,
                           OpInstrCount, IgnoredInstruction,
                           IgnoredInstruction);
  }
  BuildUnrolledShiftStep(this, BB, MI, DL, opcode, Rd, 1, 2, OpSize,
                         OpInstrCount, IgnoredInstruction, IgnoredInstruction);
  BuildUnrolledShiftStep(this, BB, MI, DL, opcode, Rd, 1, 1, OpSize,
                         OpInstrCount, IgnoredInstruction, LastInstruction);

  finalizeBundle(*BB, FirstInstruction->getIterator(),
                 std::next(LastInstruction->getIterator()));
  MI.eraseFromParent();
  return true;
}

static RL78CC::CondCodes GetOppositeBranchCondition(RL78CC::CondCodes CC) {
  switch (CC) {
  case RL78CC::RL78CC_C:
    return RL78CC::RL78CC_NC;
  case RL78CC::RL78CC_NC:
    return RL78CC::RL78CC_C;
  case RL78CC::RL78CC_Z:
    return RL78CC::RL78CC_NZ;
  case RL78CC::RL78CC_NZ:
    return RL78CC::RL78CC_Z;
  case RL78CC::RL78CC_H:
    return RL78CC::RL78CC_NH;
  case RL78CC::RL78CC_NH:
    return RL78CC::RL78CC_H;
  }
  llvm_unreachable("Invalid condition code!");
}

static bool isUncondBranchOpcode(int Opc) { return Opc == RL78::BR; }

static bool isCondBranchOpcode(int Opc) {
  return (Opc == RL78::BRCC) || (Opc == RL78::BTBF) || (Opc == RL78::BTBF_mem)
      || (Opc == RL78::BTBF_sfr) || (Opc == RL78::BTBF_saddr);
}

static bool isIndirectBranchOpcode(int Opc) { return Opc == RL78::BR_AX_cg; }

static void parseCondBranch(MachineInstr *LastInst, MachineBasicBlock *&Target,
                            SmallVectorImpl<MachineOperand> &Cond) {
  Cond.push_back(MachineOperand::CreateImm(LastInst->getOperand(1).getImm()));
  Target = LastInst->getOperand(0).getMBB();
  // if BT/BF/BTCLR instruction add the remaining 2 operands (reg and bit)
  // LastInst->dump();
  if (LastInst->getNumOperands() > 3) {
    Cond.push_back(MachineOperand::CreateImm(LastInst->getOpcode()));
    Cond.push_back(LastInst->getOperand(2));
    Cond.push_back(LastInst->getOperand(3));
  }
}

bool RL78InstrInfo::analyzeBranch(MachineBasicBlock &MBB,
                                  MachineBasicBlock *&TBB,
                                  MachineBasicBlock *&FBB,
                                  SmallVectorImpl<MachineOperand> &Cond,
                                  bool AllowModify) const {
  MachineBasicBlock::iterator I = MBB.getLastNonDebugInstr();
  // empty BB? fall-through
  if (I == MBB.end())
    return false;

  // not a branch instruction? fall-through
  if (!isUnpredicatedTerminator(*I))
    return false;

  // Get the last instruction in the block.
  MachineInstr *LastInst = &*I;
  unsigned LastOpc = LastInst->getOpcode();

  // If there is only one terminator instruction, process it.
  if (I == MBB.begin() || (!(--I)->isBranch())) {
    if (isUncondBranchOpcode(LastOpc)) {
      TBB = LastInst->getOperand(0).getMBB();
      return false;
    }
    if (isCondBranchOpcode(LastOpc)) {
      // Block ends with fall-through condbranch.
      parseCondBranch(LastInst, TBB, Cond);
      return false;
    }
    return true; // Can't handle indirect branch.
  }
  // MBB.dump();
  // Get the instruction before it if it is a terminator.
  MachineInstr *SecondLastInst = &*I;
  unsigned SecondLastOpc = SecondLastInst->getOpcode();

  // If AllowModify is true and the block ends with two or more unconditional
  // branches, delete all but the first unconditional branch.
  if (AllowModify && isUncondBranchOpcode(LastOpc)) {
    while (isUncondBranchOpcode(SecondLastOpc)) {
      LastInst->eraseFromParent();
      LastInst = SecondLastInst;
      LastOpc = LastInst->getOpcode();
      if (I == MBB.begin() || (!(--I)->isBranch())) {
        // Return now the only terminator is an unconditional branch.
        TBB = LastInst->getOperand(0).getMBB();
        return false;
      } else {
        SecondLastInst = &*I;
        SecondLastOpc = SecondLastInst->getOpcode();
      }
    }
  }

  // If there are three terminators, we don't know what sort of block this is.
  if (SecondLastInst && I != MBB.begin() && isUnpredicatedTerminator(*--I))
    return true;

  // If the block ends with a B and a Bcc, handle it.
  if (isCondBranchOpcode(SecondLastOpc) && isUncondBranchOpcode(LastOpc)) {
    parseCondBranch(SecondLastInst, TBB, Cond);
    FBB = LastInst->getOperand(0).getMBB();
    return false;
  }

  // If the block ends with two unconditional branches, handle it.  The second
  // one is not executed.
  if (isUncondBranchOpcode(SecondLastOpc) && isUncondBranchOpcode(LastOpc)) {
    TBB = SecondLastInst->getOperand(0).getMBB();
    return false;
  }

  // ...likewise if it ends with an indirect branch followed by an unconditional
  // branch.
  if (isIndirectBranchOpcode(SecondLastOpc) && isUncondBranchOpcode(LastOpc)) {
    I = LastInst;
    if (AllowModify)
      I->eraseFromParent();
    return true;
  }

  // Otherwise, can't handle this.
  return true;
}

unsigned RL78InstrInfo::insertBranch(
    MachineBasicBlock &MBB, MachineBasicBlock *TBB, MachineBasicBlock *FBB,
    ArrayRef<MachineOperand> Cond, const DebugLoc &DL, int *BytesAdded) const {
  assert(TBB && "insertBranch must not be told to insert a fallthrough");
  assert(!BytesAdded && "code size not handled");
  // MBB.dump();
  // MBB.getParent()->dump();
  if (Cond.empty()) {
    assert(!FBB && "Unconditional branch with multiple successors!");
    BuildMI(&MBB, DL, get(RL78::BR)).addMBB(TBB);
    return 1;
  }

  // Conditional branch
  unsigned CC = Cond[0].getImm();

  // is this a BT/BF/BTCLR
  if (Cond.size() > 1) {
    // Cond[1].dump();
    BuildMI(&MBB, DL, get(Cond[1].getImm()))
        .addMBB(TBB)
        .addImm(CC)
        .add(Cond[2])
        .add(Cond[3]);
    // MBB.dump();
  } else {
    BuildMI(&MBB, DL, get(RL78::BRCC)).addMBB(TBB).addImm(CC);
  }
  // do we need to insert a branch for the FBB as well?
  if (!FBB)
    return 1;

  BuildMI(&MBB, DL, get(RL78::BR)).addMBB(FBB);
  return 2;
}

unsigned RL78InstrInfo::removeBranch(MachineBasicBlock &MBB,
                                     int *BytesRemoved) const {
  assert(!BytesRemoved && "code size not handled");
  // MBB.dump();
  // MBB.getParent()->dump();
  MachineBasicBlock::iterator I = MBB.end();
  unsigned Count = 0;
  while (I != MBB.begin()) {
    --I;

    if (I->isDebugValue())
      continue;

    if (!(isUncondBranchOpcode(I->getOpcode()) ||
          isIndirectBranchOpcode(I->getOpcode()) ||
          isCondBranchOpcode(I->getOpcode())))
      break; // Not a branch.

    I->eraseFromParent();
    I = MBB.end();
    ++Count;
  }
  return Count;
}

bool RL78InstrInfo::reverseBranchCondition(
    SmallVectorImpl<MachineOperand> &Cond) const {
  RL78CC::CondCodes CC = static_cast<RL78CC::CondCodes>(Cond[0].getImm());
  Cond[0].setImm(GetOppositeBranchCondition(CC));
  return false;
}

// Commuting `AX = ADDW AX, rp` would move the value pinned to AX (a virtual
// register of the single-register class RL78AXRP) into the other operand.
bool RL78InstrInfo::findCommutedOpIndices(const MachineInstr &MI,
                                          unsigned &SrcOpIdx1,
                                          unsigned &SrcOpIdx2) const {
  if (!TargetInstrInfo::findCommutedOpIndices(MI, SrcOpIdx1, SrcOpIdx2))
    return false;
  const MachineRegisterInfo &MRI = MI.getMF()->getRegInfo();
  for (unsigned Idx : {SrcOpIdx1, SrcOpIdx2}) {
    Register R = MI.getOperand(Idx).getReg();
    if (R.isVirtual() && MRI.getRegClass(R)->getNumRegs() == 1)
      return false;
  }
  return true;
}

// LOAD8_r_arg_slot and LOAD16_rp_arg_slot read the fixed, immutable objects
// above the frame: no store in the function writes them (their loads are
// rematerialized on that ground too).
bool RL78InstrInfo::areMemAccessesTriviallyDisjoint(
    const MachineInstr &MIa, const MachineInstr &MIb) const {
  auto IsArgumentLoad = [](const MachineInstr &MI) {
    return MI.getOpcode() == RL78::LOAD8_r_arg_slot ||
           MI.getOpcode() == RL78::LOAD16_rp_arg_slot;
  };
  return IsArgumentLoad(MIa) || IsArgumentLoad(MIb);
}

// Lets MachineCopyPropagation see the moves this target emits: by the time the
// pre-emit passes run there are no COPY pseudos left for it to match.
// The 8-bit MOV_A_r_cg/MOV_r_A_cg are deliberately not listed. Their register classes
// span A and X, which are the two halves of AX, and propagating across that
// miscompiles CoreMark (wrong crclist and crcstate).
std::optional<DestSourcePair>
RL78InstrInfo::isCopyInstrImpl(const MachineInstr &MI) const {
  switch (MI.getOpcode()) {
  case RL78::MOVW_AX_rp:
  case RL78::MOVW_rp_AX:
    return DestSourcePair{MI.getOperand(0), MI.getOperand(1)};
  default:
    return std::nullopt;
  }
}

void RL78InstrInfo::copyPhysReg(MachineBasicBlock &MBB,
                                MachineBasicBlock::iterator I,
                                const DebugLoc &DL, Register DestReg,
                                Register SrcReg, bool KillSrc,
                                bool RenamableDest, bool RenamableSrc) const {
  bool AtBegin = I == MBB.begin();
  MachineBasicBlock::iterator Before = AtBegin ? I : std::prev(I);
  bool Lowering = isCopyBeingLowered(MBB, I, DestReg, SrcReg);
  buildCopy(MBB, I, Lowering ? std::next(I) : I, DL, DestReg, SrcReg, KillSrc);
  // A copy through an exchange with A or AX, or with AX saved around it:
  // which half of the exchange is unused, and whether AX has a value to
  // save, depends on what is live here.
  for (MachineBasicBlock::iterator It = AtBegin ? MBB.begin() : std::next(Before);
       It != I; ++It)
    if (isExchange(*It) || It->getOpcode() == RL78::PUSH_rp) {
      setExchangeFlags(MBB, Lowering ? &*I : nullptr);
      break;
    }
}

// Build the copy before \p I; \p After is where the liveness of a register
// used as a temporary is taken.
void RL78InstrInfo::buildCopy(MachineBasicBlock &MBB,
                              MachineBasicBlock::iterator I,
                              MachineBasicBlock::iterator After,
                              const DebugLoc &DL, Register DestReg,
                              Register SrcReg, bool KillSrc) const {
#define MACRHigh 0xFFF2
#define MACRLow 0xFFF0
  // 8 bit copy:
  if (RL78::RL78RegRegClass.contains(DestReg, SrcReg)) {
    // mov A, <...>
    if (RL78::RL78ARegRegClass.contains(DestReg)) {
      // mov A, r
      BuildMI(MBB, I, DL, get(RL78::MOV_A_r), DestReg)
          .addReg(SrcReg, getKillRegState(KillSrc));
    }
    // mov <..>, A
    else if (RL78::RL78ARegRegClass.contains(SrcReg)) {
      // mov r, A
      BuildMI(MBB, I, DL, get(RL78::MOV_r_A), DestReg)
          .addReg(SrcReg, getKillRegState(KillSrc));
    } else {
      // Last solution for 8 bit copy:
      // using xch: 3 - 5 bytes and 3 clocks
      // xch A, dst -> 1,2 bytes and clocks 1
      // mov A, src -> 1 bytes and clocks 1
      // xch A, dst -> 1,2 bytes and clocks 1
      // or using push,pop: 4 bytes and 4 clocks
      // push AX -> 1 byte and clocks 1
      // mov A, src -> 1 bytes and clocks 1
      // mov dst, A -> 1 bytes and clocks 1
      // pop AX -> 1 byte and clocks 1.
      if (MBB.getParent()->getFunction().hasOptSize() &&
          (DestReg != RL78::R0)) {
        BuildMI(MBB, I, DL, get(RL78::PUSH_rp))
            .addReg(RL78::RP0,
                    getUndefRegState(!isLiveBefore(MBB, After, RL78::RP0)));
        // mov A, r
        BuildMI(MBB, I, DL, get(RL78::MOV_A_r), RL78::R1)
            .addReg(SrcReg, getKillRegState(KillSrc));
        // mov r, A
        BuildMI(MBB, I, DL, get(RL78::MOV_r_A), DestReg)
            .addReg(RL78::R1, RegState::Kill);
        //
        BuildMI(MBB, I, DL, get(RL78::POP_rp), RL78::RP0);
      } else {
        BuildMI(MBB, I, DL, get(getXCHOpcode(DestReg)), RL78::R1)
            .addReg(DestReg, RegState::Define)
            .addReg(RL78::R1, RegState::Kill)
            .addReg(DestReg, RegState::Kill);
        // mov A, r
        BuildMI(MBB, I, DL, get(RL78::MOV_A_r), RL78::R1)
            .addReg(SrcReg, getKillRegState(KillSrc));
        //
        BuildMI(MBB, I, DL, get(getXCHOpcode(DestReg)), RL78::R1)
            .addReg(DestReg, RegState::Define)
            .addReg(RL78::R1, RegState::Kill)
            .addReg(DestReg, RegState::Kill);
      }
    }
  }
  // moving on to 16 bit copy:
  else if (RL78::RL78RPRegsRegClass.contains(DestReg, SrcReg)) {
    // movw AX, <...>
    if (RL78::RL78AXRPRegClass.contains(DestReg)) {
      // movw AX, rp
      BuildMI(MBB, I, DL, get(RL78::MOVW_AX_rp), DestReg)
          .addReg(SrcReg, getKillRegState(KillSrc));
    }
    // movw <..>, AX
    else if (RL78::RL78AXRPRegClass.contains(SrcReg)) {
      // movw rp, AX
      BuildMI(MBB, I, DL, get(RL78::MOVW_rp_AX), DestReg)
          .addReg(SrcReg, getKillRegState(KillSrc));
    }
    // movw BC/DE/HL, BC/DE/HL using push/pop 2 bytes and 2 cycles.
    // Also used for ES when it is modeled as a 16-bit RP register.
    else {
      BuildMI(MBB, I, DL, get(RL78::PUSH_rp))
          .addReg(SrcReg, getKillRegState(KillSrc));
      BuildMI(MBB, I, DL, get(RL78::POP_rp), DestReg);
    }
  }
  // 16 to 8 bit copy:
  else if (RL78::RL78RegRegClass.contains(DestReg) &&
           RL78::RL78RPRegsRegClass.contains(SrcReg)) {
    llvm_unreachable("Don't know how to copy from 16 to 8 bit reg!");
    // if the 8 bit reg is part of the 16 bit reg don't do anything
    // else do a a bit copy of the low part
    // const TargetRegisterInfo *TRI = &getRegisterInfo();
    // unsigned int source = TRI->getSubReg(SrcReg, RL78::sub_lo);
    // assert(DestReg != TRI->getSubReg(SrcReg, RL78::sub_hi) && "Unhandled copy
    // form hi part!"); if(source != DestReg)
    //  copyPhysReg(MBB, I, DL, DestReg, source, KillSrc);
  }
  // 8 to 16 bit copy:
  else if (RL78::RL78RPRegsRegClass.contains(DestReg) &&
           RL78::RL78RegRegClass.contains(SrcReg)) {
    // const TargetRegisterInfo *TRI = &getRegisterInfo();
    // unsigned int dstlo = TRI->getSubReg(SrcReg, RL78::sub_lo);
    // BuildMI(MBB, I, DL, get(RL78::MOV_A_r), DestReg).addReg(SrcReg,
    // getKillRegState(KillSrc));
    llvm_unreachable("Don't know how to copy from 8 to 16 bit reg!");
  }
  // SP reg to 16 bit reg
  else if (DestReg == RL78::SPreg && SrcReg == RL78::RP0) {
    BuildMI(MBB, I, DL, get(RL78::MOVW_SP_AX), DestReg)
        .addReg(SrcReg, getKillRegState(KillSrc));
  }
  else if (RL78::RL78RPRegsRegClass.contains(DestReg) &&
           RL78::RL78SPRegRegClass.contains(SrcReg)) {
    BuildMI(MBB, I, DL,
            get(DestReg == RL78::RP0 ? RL78::MOVW_AX_SP : RL78::MOVW_rp_SP),
            DestReg)
        .addReg(SrcReg, getKillRegState(KillSrc));
  }
  // 8 bit reg to CS
  else if (RL78::CS == DestReg && RL78::RL78Bank0RegRegClass.contains(SrcReg)) {
    if (RL78::R1 == SrcReg) {
      BuildMI(MBB, I, DL, get(RL78::MOV_CS_A), RL78::CS)
          .addReg(RL78::R1, getKillRegState(KillSrc));
    } else {
      BuildMI(MBB, I, DL, get(getXCHOpcode(SrcReg)), RL78::R1)
          .addReg(SrcReg, RegState::Define)
          .addReg(RL78::R1, RegState::Kill)
          .addReg(SrcReg, RegState::Kill);
      BuildMI(MBB, I, DL, get(RL78::MOV_CS_A), RL78::CS).addReg(RL78::R1);
      BuildMI(MBB, I, DL, get(getXCHOpcode(SrcReg)), RL78::R1)
          .addReg(SrcReg, RegState::Define)
          .addReg(RL78::R1, RegState::Kill)
          .addReg(SrcReg, RegState::Kill);
    }
  } 
  else if ((SrcReg == RL78::MACRH || SrcReg == RL78::MACRL) &&
           (DestReg == RL78::MACRH || DestReg == RL78::MACRL)) {
    // One half of MACR to the other (a MACH result that is the next MACH's
    // addend): both are memory, so the value goes through AX, which is saved
    // around it.
    BuildMI(MBB, I, DL, get(RL78::PUSH_rp))
        .addReg(RL78::RP0, getUndefRegState(!isLiveBefore(MBB, After, RL78::RP0)));
    BuildMI(MBB, I, DL, get(RL78::MOVW_rp_abs16), RL78::RP0)
        .addImm(SrcReg == RL78::MACRH ? MACRHigh : MACRLow)
        .addReg(SrcReg, RegState::Implicit | getKillRegState(KillSrc));
    BuildMI(MBB, I, DL, get(RL78::MOVW_abs16_AX))
        .addImm(DestReg == RL78::MACRH ? MACRHigh : MACRLow)
        .addReg(RL78::RP0, RegState::Kill)
        .addReg(DestReg, RegState::ImplicitDefine);
    BuildMI(MBB, I, DL, get(RL78::POP_rp), RL78::RP0);
  }
  else if (SrcReg == RL78::MACRH || SrcReg == RL78::MACRL) {
    unsigned SrcAddr = SrcReg == RL78::MACRH ? MACRHigh : MACRLow;
    // MACR is memory mapped: the copy is a load from its address. The
    // implicit use keeps it ordered after the MACH_cg that defines MACR (post-RA
    // scheduling) and keeps the MACR write before it alive (copy propagation).
    if (DestReg == RL78::RP0)
        BuildMI(MBB, I, DL, get(RL78::MOVW_rp_abs16), RL78::RP0)
            .addImm(SrcAddr)
            .addReg(SrcReg, RegState::Implicit | getKillRegState(KillSrc));
    else {
      BuildMI(MBB, I, DL, get(RL78::XCHW_AX_rp), RL78::RP0)
          .addReg(DestReg, RegState::Define)
          .addReg(RL78::RP0, RegState::Kill)
          .addReg(DestReg, RegState::Kill);
      BuildMI(MBB, I, DL, get(RL78::MOVW_rp_abs16), RL78::RP0)
            .addImm(SrcAddr)
            .addReg(SrcReg, RegState::Implicit | getKillRegState(KillSrc));
      BuildMI(MBB, I, DL, get(RL78::XCHW_AX_rp), RL78::RP0)
          .addReg(DestReg, RegState::Define)
          .addReg(RL78::RP0, RegState::Kill)
          .addReg(DestReg, RegState::Kill);
    }
  } 
  else if (DestReg == RL78::MACRH || DestReg == RL78::MACRL) {
      unsigned DestAddr = DestReg == RL78::MACRH ? MACRHigh : MACRLow;
    // A store to MACR's address; the implicit def orders it before the MACH_cg
    // that reads MACR (see the load above).
    if (SrcReg == RL78::RP0)
        BuildMI(MBB, I, DL, get(RL78::MOVW_abs16_AX))
            .addImm(DestAddr)
            .addReg(RL78::RP0, getKillRegState(KillSrc))
            .addReg(DestReg, RegState::ImplicitDefine);
    else {
      BuildMI(MBB, I, DL, get(RL78::XCHW_AX_rp), RL78::RP0)
          .addReg(SrcReg, RegState::Define)
          .addReg(RL78::RP0, RegState::Kill)
          .addReg(SrcReg, RegState::Kill);
      BuildMI(MBB, I, DL, get(RL78::MOVW_abs16_AX))
            .addImm(DestAddr)
            .addReg(RL78::RP0)
            .addReg(DestReg, RegState::ImplicitDefine);
      BuildMI(MBB, I, DL, get(RL78::XCHW_AX_rp), RL78::RP0)
          .addReg(SrcReg, RegState::Define)
          .addReg(RL78::RP0, RegState::Kill)
          .addReg(SrcReg, RegState::Kill);
    }
  }  
  else
    llvm_unreachable("Unknown copy!");
  // MovMI->addRegisterDefined(DestReg, TRI);
}

unsigned RL78InstrInfo::getInstSizeInBytes(const MachineInstr &MI) const {

  // To be larger than 8bit, to avoid to be jumped by shorter displacements.
  if (MI.isInlineAsm())
    return 512;

  switch (MI.getOpcode()) {
    // Worst case scenario for BRCC is SK_cc + BR_rel16_cg =
    // 2 + 3 = 5. And for BT/BF is MOV1 + 5 = 8.
  case RL78::BRCC:
    return 5;
  case RL78::BTBF:
  case RL78::BTBF_mem:
  case RL78::BTBF_sfr:
  case RL78::BTBF_saddr:
    return 8;
  case RL78::BR:
    return 4;
  case TargetOpcode::BUNDLE: {
    unsigned Size = 0;
    MachineBasicBlock::const_instr_iterator I = MI.getIterator();
    MachineBasicBlock::const_instr_iterator E = MI.getParent()->instr_end();
    while (++I != E && I->isInsideBundle()) {
      assert(!I->isBundle() && "No nested bundle!");
      Size += getInstSizeInBytes(*I);
    }
    return Size;
  }
  default:
    return MI.getDesc().getSize();
  }
}

/// Constants defining how certain sequences should be outlined.
///
/// \p MachineOutlinerDefault implies that the function is called with a call
/// instruction, and a return must be emitted for the outlined function frame.
///
/// That is,
///
/// I1                                 OUTLINED_FUNCTION:
/// I2 --> call OUTLINED_FUNCTION       I1
/// I3                                  I2
///                                     I3
///                                     ret
///
/// * Call construction overhead: 1 (call instruction)
/// * Frame construction overhead: 1 (return instruction)
///
/// \p MachineOutlinerTailCall implies that the function is being tail called.
/// A jump is emitted instead of a call, and the return is already present in
/// the outlined sequence. That is,
///
/// I1                                 OUTLINED_FUNCTION:
/// I2 --> jmp OUTLINED_FUNCTION       I1
/// ret                                I2
///                                    ret
///
/// * Call construction overhead: 1 (jump instruction)
/// * Frame construction overhead: 0 (don't need to return)
///
enum MachineOutlinerClass { MachineOutlinerDefault, MachineOutlinerTailCall };

static unsigned getCallFrameSize(MachineInstr &MI) {
  if (!MI.isCall())
    return 0;

  if (MI.getNumExplicitOperands() > 1 &&
      MI.getOperand(MI.getNumExplicitOperands() - 1).isImm())
    return MI.getOperand(MI.getNumExplicitOperands() - 1).getImm();
  else if (MI.getNumExplicitOperands() > 2 &&
           MI.getOperand(MI.getNumExplicitOperands() - 2).isImm())
    return MI.getOperand(MI.getNumExplicitOperands() - 2).getImm();
  return 0;
}

/// Returns a \p outliner::OutlinedFunction struct containing target-specific
/// information for a set of outlining candidates.
std::optional<std::unique_ptr<outliner::OutlinedFunction>>
RL78InstrInfo::getOutliningCandidateInfo(
    const MachineModuleInfo &MMI,
    std::vector<outliner::Candidate> &RepeatedSequenceLocs,
    unsigned MinRepeats) const {

  auto illegalOutline = [=](outliner::Candidate &C) {
    unsigned maxCallFrameSize = 0, callFrameSize;
    unsigned maxSPOffset = 0;    
    bool seenSetup = false;
    bool seenCall = false;
    
    MachineBasicBlock::iterator MBBI = C.front();
    for (;;) {
      for (unsigned i = 0; i < MBBI->getNumOperands(); ++i)
        if (MBBI->getOperand(i).getTargetFlags() == SPII::MO_OUTLINE_SP) {
          if (maxSPOffset < MBBI->getOperand(i).getImm())
            maxSPOffset = MBBI->getOperand(i).getImm();
        }
      callFrameSize = getCallFrameSize(*MBBI);
      if (callFrameSize > maxCallFrameSize)
        maxCallFrameSize = callFrameSize;
      if (MBBI->getOpcode() == RL78::CALL_STACK_SETUP && MBBI->getOperand(0).getImm() != 0)
      {
          // Unmatched frameSetup
          if(seenSetup || seenCall) 
              return true;
          seenSetup = true;
          
      }

      if(MBBI->isCall()) {          
          if(callFrameSize > 0 && (!seenSetup || seenCall))
              return true;
          seenCall = (callFrameSize > 0);
      }

       if(MBBI->getOpcode() == RL78::CALL_STACK_DESTROY && MBBI->getOperand(0).getImm() != 0) {
          // Unmatched frameDestroy
          if(!seenSetup || !seenCall) 
              return true;
          seenSetup = false;
          seenCall = false;
      }


      if (MBBI == C.back())
        break;
      ++MBBI;
    }
    if ((maxCallFrameSize + maxSPOffset + 4) > 255)
      return true;

    return seenSetup || seenCall;
  };
  // Remove candidates that need big SP adjustment
  llvm::erase_if(RepeatedSequenceLocs, illegalOutline);
  // If the sequence doesn't have enough candidates left, then we're done.
  if (RepeatedSequenceLocs.size() < MinRepeats)
    return std::nullopt;

  unsigned SequenceSize =
      std::accumulate(RepeatedSequenceLocs[0].begin(),
                      RepeatedSequenceLocs[0].end(), 0,
                      [this](unsigned Sum, const MachineInstr &MI) {
                        return Sum + getInstSizeInBytes(MI);
                      });

  if (RepeatedSequenceLocs[0].back().isTerminator()) {
    unsigned CO = Subtarget.HasFarCodeModel() ? get(RL78::BR_addr20).getSize()
                                              : get(RL78::BR_addr16).getSize();

    for (outliner::Candidate &C : RepeatedSequenceLocs)
      C.setCallInfo(MachineOutlinerTailCall, CO);

    return std::make_unique<outliner::OutlinedFunction>(
        RepeatedSequenceLocs, SequenceSize,
        0,                      // Number of bytes to emit frame.
        MachineOutlinerTailCall // Type of frame.
    );
  }
  unsigned CO = Subtarget.HasFarCodeModel() ? get(RL78::CALL_addr20).getSize()
                                            : get(RL78::CALL_addr16).getSize();
  for (outliner::Candidate &C : RepeatedSequenceLocs)
    C.setCallInfo(MachineOutlinerDefault, CO);
  return std::make_unique<outliner::OutlinedFunction>(
      RepeatedSequenceLocs, SequenceSize, 0, MachineOutlinerDefault);
}

// Whether F is an outlined function with [SP+n] operands of the function it
// was taken from, in its own body or in an outlined function it calls or
// jumps to.
static bool readsCallersFrame(const MachineModuleInfo &MMI, const Function &F,
                              unsigned Depth = 0) {
  if (!F.getName().starts_with("OUTLINED_FUNCTION_"))
    return false;
  const MachineFunction *MF = MMI.getMachineFunction(F);
  // Deeper than the outliner is ever asked to rerun: assume the worst.
  if (!MF || Depth > 16)
    return true;
  for (const MachineBasicBlock &MBB : *MF)
    for (const MachineInstr &MI : MBB)
      for (const MachineOperand &MO : MI.operands()) {
        if (MO.getTargetFlags() == SPII::MO_OUTLINE_SP ||
            MO.getTargetFlags() == SPII::MO_NO_OUTLINE_SP)
          return true;
        if (MO.isGlobal())
          if (const auto *Callee = dyn_cast<Function>(MO.getGlobal()))
            if (readsCallersFrame(MMI, *Callee, Depth + 1))
              return true;
      }
  return false;
}

/// Returns how or if \p MI should be outlined.
outliner::InstrType
RL78InstrInfo::getOutliningTypeImpl(const MachineModuleInfo &MMI,
                                    MachineBasicBlock::iterator &MIT,
                                    unsigned Flags) const {
  MachineInstr &MI = *MIT;
  // Don't allow debug values to impact outlining type.
  if (MI.isDebugInstr() || MI.isIndirectDebugValue() ||
      MI.getOpcode() == RL78::CALL_STACK_SETUP ||
      MI.getOpcode() == RL78::CALL_STACK_DESTROY)
    return outliner::InstrType::Invisible;

  // For now, disable outlining bundled instructions, since the outliner does not copy them 
  // as we expect.
  // TODO: investigate why is this happening?
  // One possible reason is the usage of the simple iterator instead of the
  // instr_iterator when creating the outlined function instructions.
  if (MI.isInsideBundle() || MI.getOpcode() == TargetOpcode::BUNDLE)
    return outliner::InstrType::Illegal;

  // At this point, KILL instructions don't really tell us much so we can go
  // ahead and skip over them.
  if (MI.isKill())
    return outliner::InstrType::Invisible;

  // Is this a tail call? If yes, we can outline as a tail call.
  if (isTailCall(MI))
    return outliner::InstrType::Legal;

  // Is this the terminator of a basic block?
  if (MI.isTerminator() || MI.isReturn()) {

    // Does its parent have any successors in its MachineFunction?
    if (MI.getParent()->succ_empty())
      return outliner::InstrType::Legal;

    // It does, so we can't tail call it.
    return outliner::InstrType::Illegal;
  }
  // Positions can't safely be outlined.
  if (MI.isPosition())
    return outliner::InstrType::Illegal;
  // Make sure none of the operands of this instruction do anything tricky.
  for (const MachineOperand &MOP : MI.operands()) {
    if (MOP.isCPI() || MOP.isJTI() || MOP.isCFIIndex() || MOP.isFI() ||
        MOP.isTargetIndex())
      return outliner::InstrType::Illegal;
  }

  switch (MI.getOpcode()) {
  // __nop/asm("nop") is used for timing delays; an outlined call/ret would
  // change the cycle count. (EI_cg/DI_cg/HALT_cg/... stay outlinable: a call/ret or
  // branch does not change the interrupt state, and interrupt epilogues such
  // as "ei; reti" are deliberately outlined for size.)
  case RL78::NOP:
    return outliner::InstrType::Illegal;
  // A skip belongs with the instruction after it.
  case RL78::SKcc:
  case RL78::SKHcc:
    return outliner::InstrType::Illegal;
  case RL78::MOVW_SP_AX:
  case RL78::MOVW_rp_SP:
  case RL78::MOVW_AX_SP:
  case RL78::MOVW_SP_i16:
  case RL78::ADDW_SP_i8:
  case RL78::SUBW_SP_i8:
  case RL78::POP_rp:
  case RL78::PUSH_rp:
    return outliner::InstrType::Illegal;
  default:
    break;
  }

  // If the callframe is too big, don't outline, since we can't use subw/addw
  // sp.
  if ((getCallFrameSize(MI) + 4) > 255)
    return outliner::InstrType::Illegal;

  // Can't outline if we can't adjust the SP.
  for (unsigned i = 0; i < MI.getNumOperands(); ++i)
    if (MI.getOperand(i).getTargetFlags() == SPII::MO_NO_OUTLINE_SP)
      return outliner::InstrType::Illegal;

  // Don't outline calls to setjmp/longjmp
  if(MI.isCall()) {
    // Get the function associated with the call.  Look at each operand and find
    // the one that represents the calle and get its name.
    const Function *Callee = nullptr;
    for (const MachineOperand &MOP : MI.operands()) {
      if (MOP.isGlobal()) {
        Callee = dyn_cast<Function>(MOP.getGlobal());
        break;
      }
    }

    // Dont't outline calls to setjmp/longjmp functions.
    if (Callee &&
        (Callee->getName() == "setjmp" || Callee->getName() == "longjmp")) {
      return outliner::InstrType::Illegal;
    }
    // An outlined function that reads its caller's frame was given [SP+n]
    // offsets for one return address on the stack. Called from another
    // outlined function (-machine-outliner-reruns) there would be two.
    if (Callee && readsCallersFrame(MMI, *Callee))
      return outliner::InstrType::Illegal;
  }

  return outliner::InstrType::Legal;
}

/// Insert a custom frame for outlined functions.
void RL78InstrInfo::buildOutlinedFrame(
    MachineBasicBlock &MBB, MachineFunction &MF,
    const outliner::OutlinedFunction &OF) const {
  // If we're a tail call, we already have a return, so don't do anything.
  if (OF.FrameConstructionID == MachineOutlinerTailCall)
    return;
  // OF.FrameOverhead > 0  --- Use this to know how much to reserve for call
  // params
  //  what to do if call frame setup is not included in outline??
  //  adjust SP+
  unsigned maxCallFrameSize = 0, callFrameSize;
  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;
    //
    for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end();
         Next != E;) {
      MachineInstr &MI = *Next;
      ++Next;
      callFrameSize = getCallFrameSize(MI);
      if (callFrameSize > maxCallFrameSize)
        maxCallFrameSize = callFrameSize;
    }
  }

  if (maxCallFrameSize > 0) {

    assert((maxCallFrameSize + 4) <= 255);
    MachineInstr *reserveStack =
        BuildMI(MF, DebugLoc(), get(RL78::SUBW_SP_i8), RL78::SPreg)
            .addReg(RL78::SPreg)
            .addImm(maxCallFrameSize);
    MachineInstr *freeStack =
        BuildMI(MF, DebugLoc(), get(RL78::ADDW_SP_i8), RL78::SPreg)
            .addReg(RL78::SPreg)
            .addImm(maxCallFrameSize);
    MBB.insert(MBB.begin(), reserveStack);
    MBB.insert(MBB.end(), freeStack);
  }

  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;
    for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end();
         Next != E;) {
      MachineInstr &MI = *Next;
      ++Next;
      for (unsigned i = 0; i < MI.getNumOperands(); ++i) {
        if (MI.getOperand(i).getTargetFlags() == SPII::MO_OUTLINE_SP &&
            MI.getOperand(i).getImm() >= maxCallFrameSize) {
            unsigned newOffset = MI.getOperand(i).getImm() + 4 +
                                  maxCallFrameSize;
          MI.getOperand(i).setImm(newOffset);
        } 
      }
      // MI.dump();
    }
  }

  // We're a normal call, so our sequence doesn't have a return instruction.
  // Add it in.
  MachineInstr *retq = BuildMI(MF, DebugLoc(), get(RL78::RET));
  MBB.insert(MBB.end(), retq);
}

/// Insert a call to an outlined function into the program.
/// Returns an iterator to the spot where we inserted the call. This must be
/// implemented by the target.
MachineBasicBlock::iterator RL78InstrInfo::insertOutlinedCall(
    Module &M, MachineBasicBlock &MBB, MachineBasicBlock::iterator &It,
    MachineFunction &MF, outliner::Candidate &C) const {
  // Is it a tail call?
  unsigned AddrSpace = MF.getFunction().getAddressSpace();
  unsigned Opcode;
  if (C.CallConstructionID == MachineOutlinerTailCall) {
    // Yes, just insert a JMP.
    Opcode = (AddrSpace == RL78AS::FarCode || Subtarget.HasFarCodeModel()) 
        ? RL78::BR_addr20 : RL78::BR_addr16;
  } else {
    // No, insert a call.
    Opcode = (AddrSpace == RL78AS::FarCode || Subtarget.HasFarCodeModel())
                 ? RL78::CALL_addr20
                 : RL78::CALL_addr16;
  }
  It = MBB.insert(It, BuildMI(MF, DebugLoc(), get(Opcode))
                          .addGlobalAddress(M.getNamedValue(MF.getName())));
  return It;
}

/// Return true if the function can safely be outlined from.
/// A function \p MF is considered safe for outlining if an outlined function
/// produced from instructions in F will produce a program which produces the
/// same output for any set of given inputs.
bool RL78InstrInfo::isFunctionSafeToOutlineFrom(
    MachineFunction &MF, bool OutlineFromLinkOnceODRs) const {
  const Function &F = MF.getFunction();
  // If we *don't* want to outline from things that could potentially be deduped
  // then return false.
  if (!OutlineFromLinkOnceODRs && F.hasLinkOnceODRLinkage())
    return false;

  // Don't outline from functions with section markings; the program could
  // expect that all the code is in the named section.
  if (F.hasSection())
    return false;

  // An outlined function is created in the default program address space, and
  // a near function cannot call a far one or the reverse.
  if (F.getAddressSpace() != F.getDataLayout().getProgramAddressSpace())
    return false;

  // It's safe to outline from MF.
  return true;
}

/// Return true if the function should be outlined from by default.
bool RL78InstrInfo::shouldOutlineFromFunctionByDefault(
    MachineFunction &MF) const {
  return MF.getFunction().hasOptSize();
}

ArrayRef<std::pair<unsigned, const char *>>
RL78InstrInfo::getSerializableDirectMachineOperandTargetFlags() const {

  static const std::pair<unsigned, const char *> Flags[] = {
      {SPII::MO_OUTLINE_SP, "rl78_outline_sp"},
      {SPII::MO_NO_OUTLINE_SP, "rl78_no_outline_sp"}};
  return llvm::ArrayRef(Flags);
}

MachineInstr *RL78InstrInfo::foldMemoryOperandImpl(
    MachineFunction &MF, MachineInstr &MI, ArrayRef<unsigned> Ops,
    int FrameIndex, MachineInstr *&CopyMI, LiveIntervals *LIS,
    VirtRegMap *VRM) const {
  CopyMI = nullptr;
  if ((MI.getOpcode() != RL78::MOV_r_i8))
    return nullptr;

  //In cases like: undef %39.sub_hi:rl78rpregs = MOV_r_imm 0
  //we need to do a +1 to get the correst stack address.
  assert(MI.getOperand(0).isReg());
  unsigned subReg = (MI.getOperand(0).getSubReg() == RL78::sub_hi)? 1 : 0;

  int64_t Imm = MI.getOperand(1).getImm();

  return BuildMI(*MI.getParent(), MI, MI.getDebugLoc(),
                 get(RL78::MOV_mSPi_i8))
      .addFrameIndex(FrameIndex)
      .addImm(subReg)
      .addImm(Imm);
}
