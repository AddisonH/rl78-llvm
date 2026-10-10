//===-- RL78LowerToHardware.cpp - Code generation MCInsts to hardware ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Code generation emits the hardware instructions of RL78InstrISA.td and a
// few pseudos that stand for one or more of them (calls, tail calls, the
// multiply and divide sequences, the low half of a 32-bit compare). This
// expands those, so that the MC layer only ever sees hardware instructions,
// and checks that every register is one the instruction encodes.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/RL78MCTargetDesc.h"
#include "RL78.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstBuilder.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/Support/ErrorHandling.h"
#include <algorithm>

using namespace llvm;

// The pseudos that are still instructions when they are printed: one or more
// hardware instructions each.
static bool lowerSpecial(const MCInst &In, SmallVectorImpl<MCInst> &Out) {
  auto Reg = [&](unsigned I) { return In.getOperand(I).getReg(); };
  // The hardware instruction with the pseudo's first operand.
  auto As = [&](unsigned Opc) {
    Out.push_back(MCInstBuilder(Opc).addOperand(In.getOperand(0)));
    return true;
  };
  MCInst XchAX = MCInstBuilder(RL78::XCH_A_X)
                     .addReg(RL78::R1)
                     .addReg(RL78::R0)
                     .addReg(RL78::R1)
                     .addReg(RL78::R0);
  MCInst Mulu = MCInstBuilder(RL78::MULU_X)
                    .addReg(RL78::RP0)
                    .addReg(RL78::R1)
                    .addReg(RL78::R0);
  switch (In.getOpcode()) {
  default:
    return false;
  case RL78::BSWAP_rp:
    Out.push_back(XchAX);
    return true;
  case RL78::BSWAP32_rp:
    Out.push_back(XchAX);
    Out.push_back(MCInstBuilder(RL78::XCHW_AX_rp)
                      .addReg(RL78::RP0)
                      .addReg(Reg(1))
                      .addReg(RL78::RP0)
                      .addReg(Reg(1)));
    Out.push_back(XchAX);
    return true;
  // The calls and jumps of code generation say what a call clobbers and
  // which jump is a tail call.
  case RL78::CALL_rp_cg:
    return As(RL78::CALL_rp);
  case RL78::CALL_addr16:
    return As(RL78::CALL_abs16);
  case RL78::CALL_addr20:
    return As(RL78::CALL_abs20);
  case RL78::CALLT_addr5:
    return As(RL78::CALLT);
  case RL78::BR_AX_cg:
    return As(RL78::BR_AX);
  case RL78::BR_addr16:
    return As(RL78::BR_abs16);
  case RL78::BR_addr20:
    return As(RL78::BR_abs20);
  case RL78::HI16_rp_addr:
    Out.push_back(MCInstBuilder(RL78::MOVW_rp_i16)
                      .addReg(Reg(0))
                      .addOperand(In.getOperand(1)));
    return true;
  // SKNZ, then the CMPW of the low words.
  case RL78::LowCMPW_rp_imm:
  case RL78::LowCMPW_rp_rp:
  case RL78::LowCMPW_rp_abs16:
  case RL78::LowCMPW_rp_saddr:
  case RL78::LowCMPW_rp_memri: {
    Out.push_back(MCInstBuilder(RL78::SKcc).addImm(RL78CC::RL78CC_NZ));
    MCInstBuilder Cmp(RL78::CMPW_AX_i16);
    switch (In.getOpcode()) {
    case RL78::LowCMPW_rp_rp:
      Cmp = MCInstBuilder(RL78::CMPW_AX_rp);
      break;
    case RL78::LowCMPW_rp_abs16:
      Cmp = MCInstBuilder(RL78::CMPW_AX_abs16);
      break;
    case RL78::LowCMPW_rp_saddr:
      Cmp = MCInstBuilder(RL78::CMPW_AX_saddrp);
      break;
    case RL78::LowCMPW_rp_memri:
      Cmp = MCInstBuilder(RL78::CMPW_AX_mHLi);
      break;
    }
    Cmp.addReg(RL78::RP0);
    for (unsigned I = 1; I < In.getNumOperands(); ++I)
      Cmp.addOperand(In.getOperand(I));
    Out.push_back(Cmp);
    return true;
  }
  case RL78::MACH_CG:
    Out.push_back(MCInstBuilder(RL78::MACH));
    return true;
  case RL78::MACHU_CG:
    Out.push_back(MCInstBuilder(RL78::MACHU));
    return true;
  // The registers that are sfrs, as their sfr addresses.
  case RL78::MUL16_rp_rp:
  case RL78::MUL32_zext_r_r:
    Out.push_back(MCInstBuilder(RL78::MULHU));
    return true;
  case RL78::MUL32_sext_r_r:
    Out.push_back(MCInstBuilder(RL78::MULH));
    return true;
  case RL78::MUL8_r_r:
  case RL78::MULU_zext_16_r_r:
  case RL78::UMUL_LOHI_16_r_r:
    Out.push_back(Mulu);
    return true;
  case RL78::UDIVREM16_r_r:
  case RL78::UDIVREM32_r_r:
    // The divide is followed by a NOP (the manual: no interrupt between).
    Out.push_back(MCInstBuilder(In.getOpcode() == RL78::UDIVREM16_r_r
                                    ? RL78::DIVHU
                                    : RL78::DIVWU));
    Out.push_back(MCInstBuilder(RL78::NOP));
    return true;
  case RL78::MOV_A_PSW_cg:
    Out.push_back(
        MCInstBuilder(RL78::MOV_A_PSW).addReg(RL78::R1).addReg(RL78::PSW));
    return true;
  case RL78::MOV_PSW_A_cg:
    Out.push_back(
        MCInstBuilder(RL78::MOV_PSW_A).addReg(RL78::PSW).addReg(RL78::R1));
    return true;
  }
}

void llvm::lowerToHardware(const MCInst &In, SmallVectorImpl<MCInst> &Out,
                           const MCInstrInfo &MII, const MCRegisterInfo &MRI) {
  // A hardware instruction already (inline asm, or code generation using
  // the hardware definitions).
  if (MII.get(In.getOpcode()).TSFlags & 1) {
    // Every register must be one the instruction encodes: the encoder takes
    // the register's number and would not notice.
    const MCInstrDesc &Desc = MII.get(In.getOpcode());
    for (unsigned I = 0, E = std::min<unsigned>(Desc.getNumOperands(),
                                                 In.getNumOperands());
         I != E; ++I) {
      const MCOperand &Op = In.getOperand(I);
      int16_t RC = Desc.operands()[I].RegClass;
      if (RC >= 0 && Op.isReg() && !MRI.getRegClass(RC).contains(Op.getReg()))
        reportFatalInternalError(Twine("RL78: ") + MII.getName(In.getOpcode()) +
                                 " with " + MRI.getName(Op.getReg()) +
                                 " as operand " + Twine(I));
    }
    Out.push_back(In);
    return;
  }
  if (lowerSpecial(In, Out))
    return;
  reportFatalInternalError(Twine("RL78: no hardware form for ") +
                           MII.getName(In.getOpcode()));
}
