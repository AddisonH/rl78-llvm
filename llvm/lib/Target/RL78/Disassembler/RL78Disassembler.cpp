//===- RL78Disassembler.cpp - Disassembler for RL78 -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The RL78 disassembler, from the TableGen'erated decoder tables of the
// hardware instructions (RL78InstrISA.td). Instructions are 1 to 5 bytes;
// the first byte(s) decide the length, so the tables are tried from the
// shortest: a shorter table never holds a prefix of a longer instruction.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/RL78MCTargetDesc.h"
#include "RL78.h"
#include "TargetInfo/RL78TargetInfo.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCDecoder.h"
#include "llvm/MC/MCDecoderOps.h"
#include "llvm/MC/MCDisassembler/MCDisassembler.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;
using namespace llvm::MCD;

#define DEBUG_TYPE "rl78-disassembler"

typedef MCDisassembler::DecodeStatus DecodeStatus;

namespace {
class RL78Disassembler : public MCDisassembler {
public:
  RL78Disassembler(const MCSubtargetInfo &STI, MCContext &Ctx)
      : MCDisassembler(STI, Ctx) {}

  DecodeStatus getInstruction(MCInst &Instr, uint64_t &Size,
                              ArrayRef<uint8_t> Bytes, uint64_t Address,
                              raw_ostream &CStream) const override;
};
} // end anonymous namespace

static MCDisassembler *createRL78Disassembler(const Target &T,
                                              const MCSubtargetInfo &STI,
                                              MCContext &Ctx) {
  return new RL78Disassembler(STI, Ctx);
}

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void
LLVMInitializeRL78Disassembler() {
  TargetRegistry::RegisterMCDisassembler(getTheRL78Target(),
                                         createRL78Disassembler);
}

static DecodeStatus addReg(MCInst &MI, MCRegister Reg) {
  MI.addOperand(MCOperand::createReg(Reg));
  return MCDisassembler::Success;
}

// A register field holds the register's hardware encoding (X..H 0-7, AX..HL
// 0, 2, 4, 6); it decodes only to a member of the operand's class.
template <unsigned RC>
static DecodeStatus decodeRegField(MCInst &MI, uint64_t Value,
                                   const MCDisassembler *Decoder) {
  const MCRegisterInfo *MRI = Decoder->getContext().getRegisterInfo();
  for (MCRegister Reg : MRI->getRegClass(RC))
    if (MRI->getEncodingValue(Reg) == Value)
      return addReg(MI, Reg);
  return MCDisassembler::Fail;
}

// A single-register class: not encoded.
template <unsigned RC>
static DecodeStatus decodeFixedReg(MCInst &MI, const MCDisassembler *Decoder) {
  const MCRegisterInfo *MRI = Decoder->getContext().getRegisterInfo();
  return addReg(MI, *MRI->getRegClass(RC).begin());
}

#define RL78_FIELD_CLASS(NAME)                                                 \
  static DecodeStatus Decode##NAME##RegisterClass(                             \
      MCInst &MI, uint64_t Value, uint64_t, const MCDisassembler *Decoder) {   \
    return decodeRegField<RL78::NAME##RegClassID>(MI, Value, Decoder);         \
  }
#define RL78_FIXED_CLASS(NAME)                                                 \
  static DecodeStatus Decode##NAME##RegisterClass(                             \
      MCInst &MI, const MCDisassembler *Decoder) {                             \
    return decodeFixedReg<RL78::NAME##RegClassID>(MI, Decoder);                \
  }
RL78_FIELD_CLASS(RL78Reg)
RL78_FIELD_CLASS(RL78Low)
RL78_FIELD_CLASS(RL78XBCEDHLReg)
RL78_FIELD_CLASS(RL78BCEDHLReg)
RL78_FIELD_CLASS(RL78RPRegs)
RL78_FIELD_CLASS(RL78BCDEHL)
RL78_FIELD_CLASS(RL78AXBCRP)
RL78_FIXED_CLASS(RL78AReg)
RL78_FIXED_CLASS(RL78XReg)
RL78_FIXED_CLASS(RL78BReg8)
RL78_FIXED_CLASS(RL78CReg8)
RL78_FIXED_CLASS(RL78AXRP)
RL78_FIXED_CLASS(RL78BCRP)
RL78_FIXED_CLASS(RL78DERP)
RL78_FIXED_CLASS(RL78HL)
RL78_FIXED_CLASS(RL78SPReg)
RL78_FIXED_CLASS(RL78RegES)
RL78_FIXED_CLASS(RL78RegCS)
RL78_FIXED_CLASS(RL78RegPSW)
#undef RL78_FIELD_CLASS
#undef RL78_FIXED_CLASS

// The encoder methods of RL78MCCodeEmitter, backwards.
static DecodeStatus decodeIsC(MCInst &MI, uint64_t V, uint64_t,
                              const MCDisassembler *) {
  return addReg(MI, V ? RL78::R2 : RL78::R3);
}
static DecodeStatus decodeIsB(MCInst &MI, uint64_t V, uint64_t,
                              const MCDisassembler *) {
  return addReg(MI, V ? RL78::R3 : RL78::R2);
}
static DecodeStatus decodeIsHL(MCInst &MI, uint64_t V, uint64_t,
                               const MCDisassembler *) {
  return addReg(MI, V ? RL78::RP6 : RL78::RP4);
}
static DecodeStatus decodeIsDE(MCInst &MI, uint64_t V, uint64_t,
                               const MCDisassembler *) {
  return addReg(MI, V ? RL78::RP4 : RL78::RP6);
}
static DecodeStatus decodeDEHLDisp(MCInst &MI, uint64_t V, uint64_t,
                                   const MCDisassembler *) {
  if (V == 1)
    return addReg(MI, RL78::RP4);
  if (V == 2)
    return addReg(MI, RL78::RP6);
  return MCDisassembler::Fail;
}

static DecodeStatus addCond(MCInst &MI, RL78CC::CondCodes CC) {
  MI.addOperand(MCOperand::createImm(CC));
  return MCDisassembler::Success;
}
static DecodeStatus decodeBcc(MCInst &MI, uint64_t V, uint64_t,
                              const MCDisassembler *) {
  static const RL78CC::CondCodes CC[4] = {RL78CC::RL78CC_C, RL78CC::RL78CC_Z,
                                          RL78CC::RL78CC_NC, RL78CC::RL78CC_NZ};
  return addCond(MI, CC[V & 3]);
}
static DecodeStatus decodeHcc(MCInst &MI, uint64_t V, uint64_t,
                              const MCDisassembler *) {
  return addCond(MI, V ? RL78CC::RL78CC_NH : RL78CC::RL78CC_H);
}
static DecodeStatus decodeBtBf(MCInst &MI, uint64_t V, uint64_t,
                               const MCDisassembler *) {
  if (V == 1)
    return addCond(MI, RL78CC::RL78CC_Z);
  if (V == 2)
    return addCond(MI, RL78CC::RL78CC_NZ);
  return MCDisassembler::Fail;
}

// saddr: FFE20H-FFF1FH from its low byte; sfr: FFF00H-FFFFFH; !addr16 of
// data: F0000H-FFFFFH.
static DecodeStatus decodeSaddr(MCInst &MI, uint64_t V, uint64_t,
                                const MCDisassembler *) {
  MI.addOperand(MCOperand::createImm((V < 0x20 ? 0xFFF00 : 0xFFE00) | V));
  return MCDisassembler::Success;
}
static DecodeStatus decodeSfr(MCInst &MI, uint64_t V, uint64_t,
                              const MCDisassembler *) {
  MI.addOperand(MCOperand::createImm(0xFFF00 | V));
  return MCDisassembler::Success;
}
static DecodeStatus decodeAddr16(MCInst &MI, uint64_t V, uint64_t,
                                 const MCDisassembler *) {
  MI.addOperand(MCOperand::createImm(0xF0000 | V));
  return MCDisassembler::Success;
}

// CALLT [addr5]: entry I is the word at 80H + 2 * I.
static DecodeStatus decodeCallt(MCInst &MI, uint64_t V, uint64_t,
                                const MCDisassembler *) {
  MI.addOperand(MCOperand::createImm(0x80 + 2 * V));
  return MCDisassembler::Success;
}

#include "RL78GenDisassemblerTables.inc"

DecodeStatus RL78Disassembler::getInstruction(MCInst &MI, uint64_t &Size,
                                              ArrayRef<uint8_t> Bytes,
                                              uint64_t Address,
                                              raw_ostream &CStream) const {
  static const uint8_t *const Tables[] = {
      DecoderTableRL788, DecoderTableRL7816, DecoderTableRL7824,
      DecoderTableRL7832, DecoderTableRL7840};
  // Byte I of the instruction is bits 8*I+7..8*I.
  uint64_t Insn = 0;
  for (unsigned Len = 1; Len <= 5 && Len <= Bytes.size(); ++Len) {
    Insn |= uint64_t(Bytes[Len - 1]) << (8 * (Len - 1));
    MI.clear();
    DecodeStatus S =
        decodeInstruction(Tables[Len - 1], MI, Insn, Address, this, STI);
    if (S != MCDisassembler::Fail) {
      Size = Len;
      return S;
    }
  }
  Size = 1;
  return MCDisassembler::Fail;
}
