//===-- RL78LowerToHardware.cpp - Code generation MCInsts to hardware ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Code generation still emits the older instruction definitions (the NAME_cg,
// LOAD*, STORE* ... of RL78InstrInfo.td), which stand for groups of hardware
// forms. This turns each into the hardware form(s) of RL78InstrISA.td that
// encode it, so that the MC layer only ever sees hardware instructions.
// Transitional: it goes as code generation moves to the hardware definitions.
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

namespace {
enum CondSet : uint8_t { CondNone, CondCZ, CondH, CondTF, Condany };

// One hardware form an older opcode may become. Operand I of the hardware
// instruction is operand Src[I] of the older one; the older operands in Drop
// are displacements that must be 0 (the short [HL] form of [HL+byte]).
struct HardwareForm {
  unsigned Old;
  unsigned New;
  uint8_t NumOps;
  int8_t Src[8];
  int8_t Drop[4];
  CondSet Cond[8];
};

const HardwareForm Forms[] = {
#include "RL78HardwareForms.inc"
};
} // namespace

static bool condFits(CondSet C, int64_t CC) {
  switch (C) {
  case CondNone:
  case Condany:
    return true;
  case CondCZ:
    return CC <= RL78CC::RL78CC_NZ;
  case CondH:
    return CC == RL78CC::RL78CC_H || CC == RL78CC::RL78CC_NH;
  case CondTF:
    return CC == RL78CC::RL78CC_Z || CC == RL78CC::RL78CC_NZ;
  }
  return false;
}

static bool fits(const HardwareForm &F, const MCInst &In,
                 const MCInstrInfo &MII, const MCRegisterInfo &MRI) {
  for (int8_t D : F.Drop) {
    if (D < 0)
      break;
    const MCOperand &Op = In.getOperand(D);
    if (!Op.isImm() || Op.getImm() != 0)
      return false;
  }
  const MCInstrDesc &Desc = MII.get(F.New);
  for (unsigned I = 0; I < F.NumOps; ++I) {
    const MCOperand &Op = In.getOperand(F.Src[I]);
    int16_t RC = Desc.operands()[I].RegClass;
    if (RC >= 0 && (!Op.isReg() || !MRI.getRegClass(RC).contains(Op.getReg())))
      return false;
    if (F.Cond[I] != CondNone && (!Op.isImm() || !condFits(F.Cond[I], Op.getImm())))
      return false;
  }
  return true;
}

static int64_t sfrAddress(MCRegister Reg) {
  switch (Reg) {
  case RL78::SPL:
    return 0xFFFF8;
  case RL78::SPH:
    return 0xFFFF9;
  case RL78::PSW:
    return 0xFFFFA;
  case RL78::CS:
    return 0xFFFFC;
  case RL78::ES:
    return 0xFFFFD;
  case RL78::PMC:
    return 0xFFFFE;
  case RL78::MEM:
    return 0xFFFFF;
  }
  llvm_unreachable("not a register that is an sfr");
}

// The older definitions that are more than one hardware instruction or whose
// operands do not line up with a hardware form's.
static bool lowerSpecial(const MCInst &In, SmallVectorImpl<MCInst> &Out) {
  auto Reg = [&](unsigned I) { return In.getOperand(I).getReg(); };
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
  case RL78::CALL_cs_rp:
    Out.push_back(MCInstBuilder(RL78::CALL_rp).addReg(Reg(0)));
    return true;
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
  static const auto Sorted = [] {
    std::vector<const HardwareForm *> V;
    for (const HardwareForm &F : Forms)
      V.push_back(&F);
    std::stable_sort(V.begin(), V.end(),
                     [](auto *A, auto *B) { return A->Old < B->Old; });
    return V;
  }();
  auto It = std::lower_bound(
      Sorted.begin(), Sorted.end(), In.getOpcode(),
      [](const HardwareForm *F, unsigned Opc) { return F->Old < Opc; });
  for (; It != Sorted.end() && (*It)->Old == In.getOpcode(); ++It) {
    const HardwareForm &F = **It;
    if (!fits(F, In, MII, MRI))
      continue;
    MCInst I;
    I.setOpcode(F.New);
    I.setLoc(In.getLoc());
    for (unsigned Op = 0; Op < F.NumOps; ++Op)
      I.addOperand(In.getOperand(F.Src[Op]));
    Out.push_back(I);
    return;
  }
  reportFatalInternalError(Twine("RL78: no hardware form for ") +
                           MII.getName(In.getOpcode()));
}
