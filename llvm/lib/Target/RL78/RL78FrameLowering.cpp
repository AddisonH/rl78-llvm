//===-- RL78FrameLowering.cpp - RL78 Frame Information ------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the RL78 implementation of TargetFrameLowering class.
//
//===----------------------------------------------------------------------===//

#include "RL78Subtarget.h"
#include "RL78MachineFunctionInfo.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

static cl::opt<bool> FrameOrderByDensity(
    "rl78-frame-order-density", cl::Hidden, cl::init(true),
    cl::desc("Place frame objects by uses per byte rather than by uses"));

RL78FrameLowering::RL78FrameLowering(const RL78Subtarget &ST)
    : TargetFrameLowering(TargetFrameLowering::StackGrowsUp, Align(2), 0) {}

unsigned RL78FrameLowering::calculateCSRegisterMask(MachineFunction &MF) const {
  uint32_t mask = ~0U;
  unsigned int sizeof_mask = CHAR_BIT * sizeof(mask);
  unsigned regNo;
  const TargetRegisterInfo *TRI =
      MF.getSubtarget<RL78Subtarget>().getRegisterInfo();
  // If a call is present we need to save/restore all registers.
  if (MF.getFrameInfo().hasCalls()) {
    mask = mask >> (sizeof_mask - (RL78::RP6 - RL78::RP0 + 1));
  } else {
    // Mark used regs.
    mask = 0;
    for (regNo = RL78::RP0; regNo <= RL78::RP6; ++regNo) {
      if (!MF.getRegInfo().reg_empty(regNo) ||
          !MF.getRegInfo().reg_empty(TRI->getSubReg(regNo, RL78::sub_lo)) ||
          !MF.getRegInfo().reg_empty(TRI->getSubReg(regNo, RL78::sub_hi)))

          mask |= 1 << (regNo - RL78::RP0);
    }
  }

  regNo = RL78::RP6 - RL78::RP0 + 1;
  if (!MF.getRegInfo().reg_empty(RL78::CS) || MF.getFrameInfo().hasCalls())
    mask |= 1 << regNo;

  regNo++;
  if (!MF.getRegInfo().reg_empty(RL78::ES) || MF.getFrameInfo().hasCalls())
    mask |= 1 << regNo;

  // MACR (S3): the interrupted code may hold a MACH_cg accumulator in it, and a
  // callee may use MACH_cg. It is saved through AX, so AX is saved too.
  regNo++;
  if (MF.getSubtarget<RL78Subtarget>().isRL78S3CoreType() &&
      (!MF.getRegInfo().reg_empty(RL78::MACRL) ||
       !MF.getRegInfo().reg_empty(RL78::MACRH) ||
       MF.getFrameInfo().hasCalls()))
    mask |= 1 << regNo | 1;

  MF.getInfo<RL78MachineFunctionInfo>()->setCSRegisterMask(mask);
  return mask;
}

void RL78FrameLowering::emitPrologue(MachineFunction &MF,
                                     MachineBasicBlock &MBB) const {
  const RL78Subtarget &Subtarget = MF.getSubtarget<RL78Subtarget>();
  MachineFrameInfo &MFI = MF.getFrameInfo();
  const RL78InstrInfo &TII =
      *static_cast<const RL78InstrInfo *>(MF.getSubtarget().getInstrInfo());
  const RL78RegisterInfo &RegInfo = *static_cast<const RL78RegisterInfo *>(
      MF.getSubtarget().getRegisterInfo());
  MachineBasicBlock::iterator MBBI = MBB.begin();
  SmallVector<unsigned, 4> CSR;
  // Debug location must be unknown since the first debug location is used
  // to determine the end of the prologue.
  DebugLoc dl;
  bool NeedsStackRealignment = RegInfo.shouldRealignStack(MF);

  // Get the number of bytes to allocate from the FrameInfo.
  unsigned NumBytes = (int)MFI.getStackSize();

  // Align the stack size (2).
  if (NumBytes & 1) 
    NumBytes++;

  unsigned NumBytesForCSRegs = 0;
  if (MF.getFunction().hasFnAttribute("brk_interrupt") ||
      MF.getFunction().hasFnAttribute("interrupt")) {
    uint64_t Specs;

    if (MF.getFunction().hasFnAttribute("interrupt")) {
      StringRef SpecsstringInterrupt =
          MF.getFunction().getFnAttribute("interrupt").getValueAsString();
      size_t HasVect = SpecsstringInterrupt.find("Vect_");
      if (HasVect != std::string::npos)
        SpecsstringInterrupt.substr(0, HasVect).getAsInteger(0, Specs);
      else
        SpecsstringInterrupt.getAsInteger(0, Specs);
    } else {
      MF.getFunction()
          .getFnAttribute("brk_interrupt")
          .getValueAsString()
          .getAsInteger(0, Specs);
    }
    // Bit 10 representes nested interrupts.

    if (Specs & 0x8)
      BuildMI(MBB, MBBI, dl, TII.get(RL78::EI_cg))
          .setMIFlags(MachineInstr::FrameSetup);
    // Bits 0, 1 and 2 represent the regiter bank:
    // 0 is a register bank was specified
    // 1,2 the bank number: 0/1/2/3.
    unsigned Bank = Specs & 0x7;

    if (Subtarget.isRL78S1CoreType() && Bank) {
      report_fatal_error("Bank selection is not supported for S1 core type");
    }

    uint32_t mask = calculateCSRegisterMask(MF);    
    // If we use the bank= specification.
    if (Bank) {
      // When no register is used or no function is called in an interrupt
      // handler, the instruction for switching register banks is not output
      // even if register bank switching is specified
      if (mask || MFI.hasCalls())
        BuildMI(MBB, MBBI, dl, TII.get(RL78::SEL))
            .addImm(Bank >> 1)
            .setMIFlags(MachineInstr::FrameSetup);
    } else {
      for (unsigned reg = 0; reg < 4; ++reg) {
        if ((1 << reg) & mask) {
          BuildMI(MBB, MBBI, dl, TII.get(RL78::PUSH_rp_cg))
              .addReg(RL78::RP0 + (reg % 4))
              .setMIFlags(MachineInstr::FrameSetup);
          NumBytesForCSRegs += 2;
        }
      }
    }
    if (mask & (1 << 5) && mask & (1 << 4)) {
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_A_cs), RL78::R1)
          .addReg(RL78::CS)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_r_A_cg), RL78::R0)
          .addReg(RL78::R1)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_A_es), RL78::R1)
          .addReg(RL78::ES)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::PUSH_rp_cg))
          .addReg(RL78::RP0)
          .setMIFlags(MachineInstr::FrameSetup);
      NumBytesForCSRegs += 2;
    } else {
      if (mask & (1 << 4)) {
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_A_cs), RL78::R1)
            .addReg(RL78::CS)
            .setMIFlags(MachineInstr::FrameSetup);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::PUSH_rp_cg))
            .addReg(RL78::RP0)
            .setMIFlags(MachineInstr::FrameSetup);
        NumBytesForCSRegs += 2;
      }
      if (mask & (1 << 5)) {
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_A_es), RL78::R1)
            .addReg(RL78::ES)
            .setMIFlags(MachineInstr::FrameSetup);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::PUSH_rp_cg))
            .addReg(RL78::RP0)
            .setMIFlags(MachineInstr::FrameSetup);
        NumBytesForCSRegs += 2;
      }
    }
    if (mask & (1 << 6)) {
      for (unsigned Addr : {0xFFF0u, 0xFFF2u}) {
        BuildMI(MBB, MBBI, dl, TII.get(RL78::LOAD16_rp_abs16), RL78::RP0)
            .addImm(Addr)
            .setMIFlags(MachineInstr::FrameSetup);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::PUSH_rp_cg))
            .addReg(RL78::RP0)
            .setMIFlags(MachineInstr::FrameSetup);
        NumBytesForCSRegs += 2;
      }
    }
  }

  // Update stack size with corrected value.
  if (NeedsStackRealignment) {
    // Reserve a slot for the old sp.
    NumBytes += 2;
    // Save AX, to be restored after we are done aligning.
    BuildMI(MBB, MBBI, dl, TII.get(RL78::PUSH_rp_cg))
        .addReg(RL78::RP0)
        .setMIFlags(MachineInstr::FrameSetup);
  }

  MFI.setStackSize(NumBytes + NumBytesForCSRegs);

  // Emit SUBW SP, #N.
  if (NumBytes > 0) {
    if (NumBytes == 2)
      BuildMI(MBB, MBBI, dl, TII.get(RL78::PUSH_rp_cg))
          .addReg(RL78::RP0)
          .setMIFlags(MachineInstr::FrameSetup);
    else if (NumBytes < 0x100)
      BuildMI(MBB, MBBI, dl, TII.get(RL78::SUBW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(NumBytes)
          .setMIFlags(MachineInstr::FrameSetup);
    else if (NumBytes < 0x1FD) {
      // Number of bytes taken by the instructions:
      // SUBW_sp_imm = 2;
      // Total:
      // 2 + 2 = 4 bytes
      // Number of cycles each instruction takes:
      // SUBW_sp_imm = 1;
      // Total:
      // 1 + 1 = 2 cycles
      BuildMI(MBB, MBBI, dl, TII.get(RL78::SUBW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(0xFE)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::SUBW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(NumBytes - 0xFE)
          .setMIFlags(MachineInstr::FrameSetup);
    } else if (NumBytes < 0x2FB) {
      // Number of bytes taken by the instructions:
      // SUBW_sp_imm = 2;
      // Total:
      // 2 + 2 + 2 = 6 bytes
      // Number of cycles each instruction takes:
      // SUBW_sp_imm = 1;
      // Total:
      // 1 + 1 + 1 = 3 cycles
      BuildMI(MBB, MBBI, dl, TII.get(RL78::SUBW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(0xFE)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::SUBW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(0xFE)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::SUBW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(NumBytes - (0xFE * 2))
          .setMIFlags(MachineInstr::FrameSetup);
    } else if (NumBytes < 0x10000) {
      if (MBB.isLiveIn(RL78::RP0) || MBB.isLiveIn(RL78::R0) ||
          MBB.isLiveIn(RL78::R1)) {
        // Number of bytes taken by the instructions:
        // XCHW_AX_rp_cg = 1; MOVW_rp_sp = 2; SUBW_rp_imm = 3; MOVW_sp_rp = 2;
        // Total:
        // 1 + 2 + 3 + 2 + 1 = 9 bytes
        // Number of cycles each instruction takes:
        // XCHW_AX_rp_cg = 1; MOVW_rp_sp = 1; SUBW_rp_imm = 1; MOVW_sp_rp = 1;
        // Total:
        // 1 + 1 + 1 + 1 + 1 = 5 cycles
        BuildMI(MBB, MBBI, dl, TII.get(RL78::XCHW_AX_rp_cg), RL78::RP0)
            .addReg(RL78::RP6, RegState::Define)
            .addReg(RL78::RP0, RegState::Kill)
            .addReg(RL78::RP6, RegState::Kill)
            .setMIFlags(MachineInstr::FrameSetup);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_rp_sp), RL78::RP0)
            .addReg(RL78::SPreg)
            .setMIFlags(MachineInstr::FrameSetup);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::SUBW_rp_imm), RL78::RP0)
            .addReg(RL78::RP0)
            .addImm(NumBytes)
            .setMIFlags(MachineInstr::FrameSetup);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_sp_rp), RL78::SPreg)
            .addReg(RL78::RP0)
            .setMIFlags(MachineInstr::FrameSetup);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::XCHW_AX_rp_cg), RL78::RP0)
            .addReg(RL78::RP6, RegState::Define)
            .addReg(RL78::RP0, RegState::Kill)
            .addReg(RL78::RP6, RegState::Kill)
            .setMIFlags(MachineInstr::FrameSetup);
      } else {
        // Number of bytes taken by the instructions:
        // MOVW_rp_sp = 2; SUBW_rp_imm = 3; MOVW_sp_rp = 2;
        // Total:
        // 2 + 3 + 2 = 7 bytes
        // Number of cycles each instruction takes:
        // MOVW_rp_sp = 1; SUBW_rp_imm = 1; MOVW_sp_rp = 1;
        // Total:
        // 1 + 1 + 1 = 3 cycles
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_rp_sp), RL78::RP0)
            .addReg(RL78::SPreg)
            .setMIFlags(MachineInstr::FrameSetup);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::SUBW_rp_imm), RL78::RP0)
            .addReg(RL78::RP0)
            .addImm(NumBytes)
            .setMIFlags(MachineInstr::FrameSetup);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_sp_rp), RL78::SPreg)
            .addReg(RL78::RP0)
            .setMIFlags(MachineInstr::FrameSetup);
      }
    }
    // Most RL78 devices just have a few KB of RAM,
    // the biggest RAM which I've seen on RL78 is 48 KB (R5F104xL) so well under
    // 64 KB (0x10000).
    else
      llvm_unreachable("Invalid stack allocation!");
  }

  if (NeedsStackRealignment) {
    // Save SP to HL.
    BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_rp_sp), RL78::RP6)
        .addReg(RL78::SPreg)
        .setMIFlags(MachineInstr::FrameSetup);

    BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_rp_sp), RL78::RP0)
        .addReg(RL78::SPreg)
        .setMIFlags(MachineInstr::FrameSetup);

    // Align to the requested boundary.
    const unsigned alignment = (~(MFI.getMaxAlign().value() - 1)) & 0xffff;
    if (MFI.getMaxAlign().value() & 0xFF00)
      BuildMI(MBB, MBBI, dl, TII.get(RL78::AND_r_imm), RL78::R1)
          .addReg(RL78::R1)
          .addImm(alignment >> 8)
          .setMIFlags(MachineInstr::FrameSetup);

    BuildMI(MBB, MBBI, dl, TII.get(RL78::XCH_A_r_cg), RL78::R1)
        .addReg(RL78::R0, RegState::Define)
        .addReg(RL78::R1, RegState::Kill)
        .addReg(RL78::R0, RegState::Kill)
        .setMIFlags(MachineInstr::FrameSetup);
    BuildMI(MBB, MBBI, dl, TII.get(RL78::AND_r_imm), RL78::R1)
        .addReg(RL78::R1)
        .addImm(alignment & 0xff)
        .setMIFlags(MachineInstr::FrameSetup);
    BuildMI(MBB, MBBI, dl, TII.get(RL78::XCH_A_r_cg), RL78::R1)
        .addReg(RL78::R0, RegState::Define)
        .addReg(RL78::R1, RegState::Kill)
        .addReg(RL78::R0, RegState::Kill)
        .setMIFlags(MachineInstr::FrameSetup);

    // Change SP to the new aligned address.
    BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_sp_rp), RL78::SPreg)
        .addReg(RL78::RP0, RegState::Kill)
        .setMIFlags(MachineInstr::FrameSetup);

    // Save the old sp just above the new stack start.
    BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_AX_rp_cg), RL78::RP0)
        .addReg(RL78::RP6)
        .setMIFlags(MachineInstr::FrameSetup);
    if (isUInt<8>(NumBytes)) {
      BuildMI(MBB, MBBI, dl, TII.get(RL78::STORE16_stack_slot_rp))
          .addReg(RL78::SPreg)
          .addImm(NumBytes - 2)
          .addReg(RL78::RP0, RegState::Kill)
          .setMIFlags(MachineInstr::FrameSetup);

      // Restore old ax value.
      BuildMI(MBB, MBBI, dl, TII.get(RL78::LOAD16_rp_rpi), RL78::RP0)
          .addReg(RL78::RP6, RegState::Kill)
          .addImm(NumBytes)
          .setMIFlags(MachineInstr::FrameSetup);

    } else if (isUInt<16>(NumBytes + 2)) {
      // Store using word[BC], save the old sp.
      BuildMI(MBB, MBBI, dl, TII.get(RL78::PUSH_rp_cg))
          .addReg(RL78::RP2, RegState::Kill)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_rp_sp), RL78::RP2)
          .addReg(RL78::SPreg)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::STORE16_rpi_rp))
          .addReg(RL78::RP2, RegState::Kill)
          .addImm(NumBytes)
          .addReg(RL78::RP0, RegState::Kill)
          .setMIFlags(MachineInstr::FrameSetup);

      // Restore old ax value.
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_AX_rp_cg), RL78::RP0)
          .addReg(RL78::RP6, RegState::Kill)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_rp_AX_cg), RL78::RP2)
          .addReg(RL78::RP0, RegState::Kill)
          .setMIFlags(MachineInstr::FrameSetup);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::LOAD16_rp_rpi), RL78::RP0)
          .addReg(RL78::RP2, RegState::Kill)
          .addImm(NumBytes)
          .setMIFlags(MachineInstr::FrameSetup);

      BuildMI(MBB, MBBI, dl, TII.get(RL78::POP_rp_cg), RL78::RP2)
          .setMIFlags(MachineInstr::FrameSetup);
    } else
      llvm_unreachable("Invalid stack offset!");
  }

}

MachineBasicBlock::iterator RL78FrameLowering::eliminateCallFramePseudoInstr(
    MachineFunction &MF, MachineBasicBlock &MBB,
    MachineBasicBlock::iterator I) const {

  const RL78InstrInfo &TII =
      *static_cast<const RL78InstrInfo *>(MF.getSubtarget().getInstrInfo());

  int64_t Amount = I->getOperand(0).getImm();
  const DebugLoc &DL = I->getDebugLoc();

  if (I->getOpcode() == TII.getCallFrameSetupOpcode())
    BuildMI(MBB, I, DL, TII.get(RL78::CALL_STACK_SETUP)).addImm(Amount);
  else
    BuildMI(MBB, I, DL, TII.get(RL78::CALL_STACK_DESTROY)).addImm(Amount);
  return MBB.erase(I);
}

void RL78FrameLowering::emitEpilogue(MachineFunction &MF,
                                     MachineBasicBlock &MBB) const {
  MachineBasicBlock::iterator MBBI = MBB.getLastNonDebugInstr();
  const TargetRegisterInfo *TRI =
      MF.getSubtarget<RL78Subtarget>().getRegisterInfo();
  // We check around RET_cg to see if rp0, r0 or r1 are LiveIn or not
  bool RP0Live = MBB.computeRegisterLiveness(TRI, RL78::RP0, MBBI) ==
                 llvm::MachineBasicBlock::LivenessQueryResult::LQR_Live;
  bool R0Live = MBB.computeRegisterLiveness(TRI, RL78::R0, MBBI) ==
                llvm::MachineBasicBlock::LivenessQueryResult::LQR_Live;
  bool R1Live = MBB.computeRegisterLiveness(TRI, RL78::R1, MBBI) ==
                llvm::MachineBasicBlock::LivenessQueryResult::LQR_Live;
  const RL78InstrInfo &TII =
      *static_cast<const RL78InstrInfo *>(MF.getSubtarget().getInstrInfo());
  DebugLoc dl = MBBI->getDebugLoc();
  // if (!FuncInfo->isLeafProc()) {
  //  return;
  //}
  MachineFrameInfo &MFI = MF.getFrameInfo();

  int NumBytes = (int)MFI.getStackSize();
  // if (NumBytes == 0)
  // return;

  unsigned NumBytesForCSRegs = 0;
  uint64_t Specs;
  uint32_t mask;
  unsigned Bank;

  if (MF.getFunction().hasFnAttribute("brk_interrupt") ||
      MF.getFunction().hasFnAttribute("interrupt")) {

    if (MF.getFunction().hasFnAttribute("interrupt")) {
      StringRef SpecsstringInterrupt =
          MF.getFunction().getFnAttribute("interrupt").getValueAsString();
      size_t HasVect = SpecsstringInterrupt.find("Vect_");
      if (HasVect != std::string::npos)
        SpecsstringInterrupt.substr(0, HasVect).getAsInteger(0, Specs);
      else
        SpecsstringInterrupt.getAsInteger(0, Specs);
    } else {
      MF.getFunction()
          .getFnAttribute("brk_interrupt")
          .getValueAsString()
          .getAsInteger(0, Specs);
    }
    // Bits 0, 1 and 2 represent the regiter bank:
    // 0 is a register bank was specified
    // 1,2 the bank number: 0/1/2/3.
    Bank = Specs & 0x7;
    // In case we use the bank= sepcification, we don't need to set the register
    // bank back to 0 becuase the the hardware does this automatically (RBS0 and
    // RBS1 bits are part of PSW register): "The data saved to the stack returns
    // to the PC and the PSW, and the program returns from the interrupt
    // servicing routine. "
    mask = MF.getInfo<RL78MachineFunctionInfo>()->getCSRegisterMask();

    if (mask & (1 << 5) && mask & (1 << 4)) {
      NumBytesForCSRegs += 2;
    } else {
      if (mask & (1 << 5))
        NumBytesForCSRegs += 2;
      if (mask & (1 << 4))
        NumBytesForCSRegs += 2;
    }

    if (mask & (1 << 6))
      NumBytesForCSRegs += 4;

    if (!Bank) {
      for (unsigned reg = 4; reg > 0; --reg)
        if ((1 << (reg - 1)) & mask)
          NumBytesForCSRegs += 2;
    }
  }

  unsigned NumBytesAdjusted = NumBytes - NumBytesForCSRegs;


  // Restore the old SP.
  const RL78RegisterInfo &RegInfo = *static_cast<const RL78RegisterInfo *>(
      MF.getSubtarget().getRegisterInfo());

  if (RegInfo.shouldRealignStack(MF)) {
    BuildMI(MBB, MBBI, dl, TII.get(RL78::XCHW_AX_rp_cg), RL78::RP0)
        .addReg(RL78::RP6, RegState::Define)
        .addReg(RL78::RP0, RegState::Kill)
        .addReg(RL78::RP6, RegState::Kill)
        .setMIFlags(MachineInstr::FrameDestroy);

    if (isUInt<8>(NumBytesAdjusted - 2))
      BuildMI(MBB, MBBI, dl, TII.get(RL78::LOAD16_rp_stack_slot), RL78::RP0)
          .addReg(RL78::SPreg)
          .addImm(NumBytesAdjusted - 2)
          .setMIFlags(MachineInstr::FrameDestroy);
    else if (isUInt<16>(NumBytesAdjusted)) {
      // Load using word[BC], restore the old sp.
      BuildMI(MBB, MBBI, dl, TII.get(RL78::PUSH_rp_cg))
          .addReg(RL78::RP2, RegState::Kill)
          .setMIFlags(MachineInstr::FrameDestroy);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_rp_sp), RL78::RP2)
          .addReg(RL78::SPreg)
          .setMIFlags(MachineInstr::FrameDestroy);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::LOAD16_rp_rpi), RL78::RP0)
          .addReg(RL78::RP2, RegState::Kill)
          .addImm(NumBytesAdjusted)
          .setMIFlags(MachineInstr::FrameDestroy);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::POP_rp_cg), RL78::RP2)
          .setMIFlags(MachineInstr::FrameDestroy);
    } else
      llvm_unreachable("Invalid stack offset!");

    BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_sp_rp), RL78::SPreg)
        .addReg(RL78::RP0)
        .setMIFlags(MachineInstr::FrameDestroy);
    BuildMI(MBB, MBBI, dl, TII.get(RL78::XCHW_AX_rp_cg), RL78::RP0)
        .addReg(RL78::RP6, RegState::Define)
        .addReg(RL78::RP0, RegState::Kill)
        .addReg(RL78::RP6, RegState::Kill)
        .setMIFlags(MachineInstr::FrameDestroy);
    // Free up the slot used to save AX in the prologue.
    NumBytesAdjusted += 2;
  }

  if (NumBytesAdjusted != 0) {
    if (NumBytesAdjusted == 2) 
      BuildMI(MBB, MBBI, dl, TII.get(RL78::POP_rp_cg), RL78::RP6)
          .setMIFlags(MachineInstr::FrameDestroy);
    else if (NumBytesAdjusted < 0x100)
      BuildMI(MBB, MBBI, dl, TII.get(RL78::ADDW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(NumBytesAdjusted)
          .setMIFlags(MachineInstr::FrameDestroy);
    else if (NumBytesAdjusted < 0x1FD) {
      // Number of bytes taken by the instructions:
      // ADDW_sp_imm = 2;
      // Total:
      // 2 + 2 = 4 bytes
      // Number of cycles each instruction takes:
      // ADDW_sp_imm = 1;
      // Total:
      // 1 + 1 = 2 cycles
      BuildMI(MBB, MBBI, dl, TII.get(RL78::ADDW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(0xFE)
          .setMIFlags(MachineInstr::FrameDestroy);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::ADDW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(NumBytesAdjusted - 0xFE)
          .setMIFlags(MachineInstr::FrameDestroy);
    } else if (NumBytesAdjusted < 0x2FB) {
      // Number of bytes taken by the instructions:
      // ADDW_sp_imm = 2;
      // Total:
      // 2 + 2 + 2 = 6 bytes
      // Number of cycles each instruction takes:
      // ADDW_sp_imm = 1;
      // Total:
      // 1 + 1 + 1 = 3 cycles
      BuildMI(MBB, MBBI, dl, TII.get(RL78::ADDW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(0xFE)
          .setMIFlags(MachineInstr::FrameDestroy);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::ADDW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(0xFE)
          .setMIFlags(MachineInstr::FrameDestroy);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::ADDW_sp_imm), RL78::SPreg)
          .addReg(RL78::SPreg)
          .addImm(NumBytesAdjusted - (0xFE * 2))
          .setMIFlags(MachineInstr::FrameDestroy);
    } else if (NumBytesAdjusted < 0x10000) {
      if (RP0Live || R0Live || R1Live) {
        // Number of bytes taken by the instructions:
        // XCHW_AX_rp_cg = 1; MOVW_rp_sp = 2; ADDW_rp_imm = 3; MOVW_sp_rp = 2;
        // Total:
        // 1 + 2 + 3 + 2 + 1 = 9 bytes
        // Number of cycles each instruction takes:
        // XCHW_AX_rp_cg = 1; MOVW_rp_sp = 1; ADDW_rp_imm = 1; MOVW_sp_rp = 1;
        // Total:
        // 1 + 1 + 1 + 1 + 1 = 5 cycles

        BuildMI(MBB, MBBI, dl, TII.get(RL78::XCHW_AX_rp_cg), RL78::RP0)
            .addReg(RL78::RP6, RegState::Define)
            .addReg(RL78::RP0, RegState::Kill)
            .addReg(RL78::RP6, RegState::Kill)
            .setMIFlags(MachineInstr::FrameDestroy);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_rp_sp), RL78::RP0)
            .addReg(RL78::SPreg)
            .setMIFlags(MachineInstr::FrameDestroy);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::ADDW_rp_imm), RL78::RP0)
            .addReg(RL78::RP0)
            .addImm(NumBytesAdjusted)
            .setMIFlags(MachineInstr::FrameDestroy);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_sp_rp), RL78::SPreg)
            .addReg(RL78::RP0)
            .setMIFlags(MachineInstr::FrameDestroy);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::XCHW_AX_rp_cg), RL78::RP0)
            .addReg(RL78::RP6, RegState::Define)
            .addReg(RL78::RP0, RegState::Kill)
            .addReg(RL78::RP6, RegState::Kill)
            .setMIFlags(MachineInstr::FrameDestroy);
      } else {
        // Number of bytes taken by the instructions:
        // MOVW_rp_sp = 2; ADDW_rp_imm = 3; MOVW_sp_rp = 2;
        // Total:
        // 2 + 3 + 2 = 7 bytes
        // Number of cycles each instruction takes:
        // MOVW_rp_sp = 1; ADDW_rp_imm = 1; MOVW_sp_rp = 1;
        // Total:
        // 1 + 1 + 1 = 3 cycles

        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_rp_sp), RL78::RP0)
            .addReg(RL78::SPreg)
            .setMIFlags(MachineInstr::FrameDestroy);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::ADDW_rp_imm), RL78::RP0)
            .addReg(RL78::RP0)
            .addImm(NumBytesAdjusted)
            .setMIFlags(MachineInstr::FrameDestroy);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOVW_sp_rp), RL78::SPreg)
            .addReg(RL78::RP0)
            .setMIFlags(MachineInstr::FrameDestroy);
      }
    } else
      llvm_unreachable("Invalid stack allocation!");
  }

  if (MF.getFunction().hasFnAttribute("brk_interrupt") ||
      MF.getFunction().hasFnAttribute("interrupt")) {
    if (mask & (1 << 6)) {
      for (unsigned Addr : {0xFFF2u, 0xFFF0u}) {
        BuildMI(MBB, MBBI, dl, TII.get(RL78::POP_rp_cg), RL78::RP0)
            .setMIFlags(MachineInstr::FrameDestroy);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::STORE16_abs16_rp))
            .addImm(Addr)
            .addReg(RL78::RP0)
            .setMIFlags(MachineInstr::FrameDestroy);
        NumBytes -= 2;
      }
    }
    if (mask & (1 << 5) && mask & (1 << 4)) {
      BuildMI(MBB, MBBI, dl, TII.get(RL78::POP_rp_cg), RL78::RP0)
          .setMIFlags(MachineInstr::FrameDestroy);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_es_A), RL78::ES)
          .addReg(RL78::R1)
          .setMIFlags(MachineInstr::FrameDestroy);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_A_r_cg), RL78::R1)
          .addReg(RL78::R0)
          .setMIFlags(MachineInstr::FrameDestroy);
      BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_cs_A), RL78::CS)
          .addReg(RL78::R1)
          .setMIFlags(MachineInstr::FrameDestroy);
      NumBytes -= 2;
    } else {
      if (mask & (1 << 5)) {
        BuildMI(MBB, MBBI, dl, TII.get(RL78::POP_rp_cg), RL78::RP0)
            .setMIFlags(MachineInstr::FrameDestroy);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_es_A), RL78::ES)
            .addReg(RL78::R1)
            .setMIFlags(MachineInstr::FrameDestroy);
        NumBytes -= 2;
      }
      if (mask & (1 << 4)) {
        BuildMI(MBB, MBBI, dl, TII.get(RL78::POP_rp_cg), RL78::RP0)
            .setMIFlags(MachineInstr::FrameDestroy);
        BuildMI(MBB, MBBI, dl, TII.get(RL78::MOV_cs_A), RL78::CS)
            .addReg(RL78::R1)
            .setMIFlags(MachineInstr::FrameDestroy);
        NumBytes -= 2;
      }
    }

    if (!Bank) {
      for (unsigned reg = 4; reg > 0; --reg) {
        if ((1 << (reg - 1)) & mask) {
          BuildMI(MBB, MBBI, dl, TII.get(RL78::POP_rp_cg),
                  RL78::RP0 + ((reg - 1) % 4))
              .setMIFlags(MachineInstr::FrameDestroy);
          NumBytes -= 2;
        }
      }
    }
  }
}

bool RL78FrameLowering::hasReservedCallFrame(const MachineFunction &MF) const {
  // Reserve call frame if there are no variable sized objects on the stack.
  return !MF.getFrameInfo().hasVarSizedObjects();
}

// hasFP - Return true if the specified function should have a dedicated frame
// pointer register.  This is true if the function has variable sized allocas or
// if frame pointer elimination is disabled.
bool RL78FrameLowering::hasFPImpl(const MachineFunction &MF) const {
  #ifndef NDEBUG
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  assert(!MFI.hasVarSizedObjects() && "Functions requiring a frame pointer are not supported.");
  #endif
  return false;
}

StackOffset RL78FrameLowering::getFrameIndexReference(const MachineFunction &MF, int FI,
                                              Register &FrameReg) const {
  const RL78Subtarget &Subtarget = MF.getSubtarget<RL78Subtarget>();
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  const RL78RegisterInfo *RegInfo = Subtarget.getRegisterInfo();

  int64_t FrameOffset = MFI.getObjectOffset(FI);
  auto stackSize = MFI.getStackSize();
  if ((FI < 0) && (FrameOffset >= 0))
    FrameReg = RL78::SPreg;
  else if (RegInfo->shouldRealignStack(MF) && (FI < 0))
    // References to passed parameters need to load the old SP first.
    FrameReg = RL78::RP4;
  else
    FrameReg = RegInfo->getFrameRegister(MF);

  if (FI < 0) {
    // The return address is a special case.
    if (FrameOffset == -2)
      FrameOffset = stackSize;
    else if (FrameOffset < 0)
      FrameOffset = stackSize - FrameOffset;
    if (FrameReg == RL78::RP4)
      FrameOffset += 2;
  }
  return StackOffset::getFixed(FrameOffset);
}

bool RL78FrameLowering::isLeafProc(MachineFunction &MF) const {
  return !MF.getFrameInfo().hasCalls();
}

namespace {
// Struct used by orderFrameObjects to help sort the stack objects.
struct RL78FrameSortingObject {
  bool IsValid = false;       // true if we care about this Object.
  unsigned ObjectIndex = 0;   // Index of Object into MFI list.
  unsigned ObjectNumUses = 0; // Object static number of uses.
  unsigned ObjectSize = 0;    // Object size in bytes.
};

struct RL78FrameSortingComparator {
  inline bool operator()(const RL78FrameSortingObject &A,
                         const RL78FrameSortingObject &B) {
    // For consistency in our comparison, all invalid objects are placed
    // at the end. This also allows us to stop walking when we hit the
    // first invalid item after it's all sorted.
    if (!A.IsValid)
      return false;
    if (!B.IsValid)
      return true;

    // Uses per byte, highest first (closest to SP): a large array is
    // addressed by computing its base once, so its offset hardly matters,
    // while a spill slot beyond [SP+255] costs a sequence through BC at
    // every access. Compare A.uses / A.size > B.uses / B.size without a
    // division; equal densities keep the more used object first.
    if (FrameOrderByDensity) {
      uint64_t DA = uint64_t(A.ObjectNumUses) * std::max(B.ObjectSize, 1u);
      uint64_t DB = uint64_t(B.ObjectNumUses) * std::max(A.ObjectSize, 1u);
      if (DA != DB)
        return DA > DB;
    }
    return A.ObjectNumUses > B.ObjectNumUses;
  }
};
} // namespace

// Order frame objects:
// We want to place the more densely used objects first (lower address)
// because we use [SP+offset] when offset < 256 and offset[BC] when offset >=
// 256. This will improve both code size and speed.
void RL78FrameLowering::orderFrameObjects(
    const MachineFunction &MF, SmallVectorImpl<int> &objectsToAllocate) const {
  const MachineFrameInfo &MFI = MF.getFrameInfo();

  // Don't waste time if there's nothing to do.
  if (objectsToAllocate.empty())
    return;

  // Create an array of all MFI objects. We won't need all of these
  // objects, but we're going to create a full array of them to make
  // it easier to index into when we're counting "uses" down below.
  // We want to be able to easily/cheaply access an object by simply
  // indexing into it, instead of having to search for it every time.
  std::vector<RL78FrameSortingObject> SortingObjects(MFI.getObjectIndexEnd());

  // Walk the objects we care about and mark them as such in our working
  // struct.
  int ObjectsSize = 0;
  for (auto &Obj : objectsToAllocate) {
    SortingObjects[Obj].IsValid = true;
    SortingObjects[Obj].ObjectIndex = Obj;
    SortingObjects[Obj].ObjectSize = MFI.getObjectSize(Obj);
    ObjectsSize += MFI.getObjectSize(Obj);
  }

  if (ObjectsSize < 256)
    return;

  // Count the number of uses for each object.
  for (auto &MBB : MF) {
    for (auto &MI : MBB) {
      if (MI.isDebugInstr())
        continue;
      for (const MachineOperand &MO : MI.operands()) {
        // Check to see if it's a local stack symbol.
        if (!MO.isFI())
          continue;
        int Index = MO.getIndex();
        // Check to see if it falls within our range, and is tagged
        // to require ordering.
        if (Index >= 0 && Index < MFI.getObjectIndexEnd())
          SortingObjects[Index].ObjectNumUses++;
      }
    }
  }
  // Sort the objects using X86FrameSortingAlgorithm (see its comment for
  // info).
  llvm::stable_sort(SortingObjects, RL78FrameSortingComparator());

  // Now modify the original list to represent the final order that
  // we want.
  int i = 0;
  for (auto &Obj : SortingObjects) {
    // All invalid items are sorted at the end, so it's safe to stop.
    if (!Obj.IsValid)
      break;
    objectsToAllocate[i++] = Obj.ObjectIndex;
  }
}
