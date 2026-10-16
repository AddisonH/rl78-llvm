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

static DecodeStatus addReg(MCInst &MI, unsigned Reg) {
  MI.addOperand(MCOperand::createReg(Reg));
  return MCDisassembler::Success;
}

// A register field holds the register's hardware encoding: X, A, C, B, E, D,
// L, H are 0-7 and AX, BC, DE, HL are 0, 2, 4, 6. Each table holds the
// members of one class at their encodings, and no register elsewhere.
static const unsigned RegDecoderTable[] = {RL78::R0, RL78::R1, RL78::R2,
                                           RL78::R3, RL78::R4, RL78::R5,
                                           RL78::R6, RL78::R7};
static const unsigned LowDecoderTable[] = {RL78::R0, RL78::R1, RL78::R2,
                                           RL78::R3};
static const unsigned XBCEDHLDecoderTable[] = {
    RL78::R0, RL78::NoRegister, RL78::R2, RL78::R3,
    RL78::R4, RL78::R5,         RL78::R6, RL78::R7};
static const unsigned BCEDHLDecoderTable[] = {
    RL78::NoRegister, RL78::NoRegister, RL78::R2, RL78::R3,
    RL78::R4,         RL78::R5,         RL78::R6, RL78::R7};
static const unsigned RPDecoderTable[] = {
    RL78::RP0, RL78::NoRegister, RL78::RP2, RL78::NoRegister,
    RL78::RP4, RL78::NoRegister, RL78::RP6};
static const unsigned BCDEHLDecoderTable[] = {
    RL78::NoRegister, RL78::NoRegister, RL78::RP2, RL78::NoRegister,
    RL78::RP4,        RL78::NoRegister, RL78::RP6};
static const unsigned AXBCDecoderTable[] = {RL78::RP0, RL78::NoRegister,
                                            RL78::RP2};

static DecodeStatus decodeRegFromTable(MCInst &MI, const unsigned *Table,
                                       unsigned Size, uint64_t Value) {
  if (Value >= Size || Table[Value] == RL78::NoRegister)
    return MCDisassembler::Fail;
  return addReg(MI, Table[Value]);
}

static DecodeStatus DecodeRL78RegRegisterClass(MCInst &MI, uint64_t Value,
                                               uint64_t Address,
                                               const MCDisassembler *Decoder) {
  return decodeRegFromTable(MI, RegDecoderTable, std::size(RegDecoderTable),
                            Value);
}
static DecodeStatus DecodeRL78LowRegisterClass(MCInst &MI, uint64_t Value,
                                               uint64_t Address,
                                               const MCDisassembler *Decoder) {
  return decodeRegFromTable(MI, LowDecoderTable, std::size(LowDecoderTable),
                            Value);
}
static DecodeStatus
DecodeRL78XBCEDHLRegRegisterClass(MCInst &MI, uint64_t Value, uint64_t Address,
                                  const MCDisassembler *Decoder) {
  return decodeRegFromTable(MI, XBCEDHLDecoderTable,
                            std::size(XBCEDHLDecoderTable), Value);
}
static DecodeStatus
DecodeRL78BCEDHLRegRegisterClass(MCInst &MI, uint64_t Value, uint64_t Address,
                                 const MCDisassembler *Decoder) {
  return decodeRegFromTable(MI, BCEDHLDecoderTable,
                            std::size(BCEDHLDecoderTable), Value);
}
static DecodeStatus
DecodeRL78RPRegsRegisterClass(MCInst &MI, uint64_t Value, uint64_t Address,
                              const MCDisassembler *Decoder) {
  return decodeRegFromTable(MI, RPDecoderTable, std::size(RPDecoderTable),
                            Value);
}
static DecodeStatus
DecodeRL78BCDEHLRegisterClass(MCInst &MI, uint64_t Value, uint64_t Address,
                              const MCDisassembler *Decoder) {
  return decodeRegFromTable(MI, BCDEHLDecoderTable,
                            std::size(BCDEHLDecoderTable), Value);
}
static DecodeStatus
DecodeRL78AXBCRPRegisterClass(MCInst &MI, uint64_t Value, uint64_t Address,
                              const MCDisassembler *Decoder) {
  return decodeRegFromTable(MI, AXBCDecoderTable, std::size(AXBCDecoderTable),
                            Value);
}

// Single-register classes: not encoded.
static DecodeStatus DecodeRL78ARegRegisterClass(MCInst &MI,
                                                const MCDisassembler *Decoder) {
  return addReg(MI, RL78::R1);
}
static DecodeStatus DecodeRL78XRegRegisterClass(MCInst &MI,
                                                const MCDisassembler *Decoder) {
  return addReg(MI, RL78::R0);
}
static DecodeStatus
DecodeRL78BReg8RegisterClass(MCInst &MI, const MCDisassembler *Decoder) {
  return addReg(MI, RL78::R3);
}
static DecodeStatus
DecodeRL78CReg8RegisterClass(MCInst &MI, const MCDisassembler *Decoder) {
  return addReg(MI, RL78::R2);
}
static DecodeStatus DecodeRL78AXRPRegisterClass(MCInst &MI,
                                                const MCDisassembler *Decoder) {
  return addReg(MI, RL78::RP0);
}
static DecodeStatus DecodeRL78BCRPRegisterClass(MCInst &MI,
                                                const MCDisassembler *Decoder) {
  return addReg(MI, RL78::RP2);
}
static DecodeStatus DecodeRL78DERPRegisterClass(MCInst &MI,
                                                const MCDisassembler *Decoder) {
  return addReg(MI, RL78::RP4);
}
static DecodeStatus DecodeRL78HLRegisterClass(MCInst &MI,
                                              const MCDisassembler *Decoder) {
  return addReg(MI, RL78::RP6);
}
static DecodeStatus
DecodeRL78SPRegRegisterClass(MCInst &MI, const MCDisassembler *Decoder) {
  return addReg(MI, RL78::SPreg);
}
static DecodeStatus
DecodeRL78RegESRegisterClass(MCInst &MI, const MCDisassembler *Decoder) {
  return addReg(MI, RL78::ES);
}
static DecodeStatus
DecodeRL78RegCSRegisterClass(MCInst &MI, const MCDisassembler *Decoder) {
  return addReg(MI, RL78::CS);
}
static DecodeStatus
DecodeRL78RegPSWRegisterClass(MCInst &MI, const MCDisassembler *Decoder) {
  return addReg(MI, RL78::PSW);
}

// The encoder methods of RL78MCCodeEmitter, backwards.
static DecodeStatus decodeIsC(MCInst &MI, uint64_t V, uint64_t Address,
                              const MCDisassembler *Decoder) {
  return addReg(MI, V ? RL78::R2 : RL78::R3);
}
static DecodeStatus decodeIsB(MCInst &MI, uint64_t V, uint64_t Address,
                              const MCDisassembler *Decoder) {
  return addReg(MI, V ? RL78::R3 : RL78::R2);
}
static DecodeStatus decodeIsHL(MCInst &MI, uint64_t V, uint64_t Address,
                               const MCDisassembler *Decoder) {
  return addReg(MI, V ? RL78::RP6 : RL78::RP4);
}
static DecodeStatus decodeIsDE(MCInst &MI, uint64_t V, uint64_t Address,
                               const MCDisassembler *Decoder) {
  return addReg(MI, V ? RL78::RP4 : RL78::RP6);
}
static DecodeStatus decodeDEHLDisp(MCInst &MI, uint64_t V, uint64_t Address,
                                   const MCDisassembler *Decoder) {
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
static DecodeStatus decodeBcc(MCInst &MI, uint64_t V, uint64_t Address,
                              const MCDisassembler *Decoder) {
  static const RL78CC::CondCodes CC[4] = {RL78CC::RL78CC_C, RL78CC::RL78CC_Z,
                                          RL78CC::RL78CC_NC, RL78CC::RL78CC_NZ};
  return addCond(MI, CC[V & 3]);
}
static DecodeStatus decodeHcc(MCInst &MI, uint64_t V, uint64_t Address,
                              const MCDisassembler *Decoder) {
  return addCond(MI, V ? RL78CC::RL78CC_NH : RL78CC::RL78CC_H);
}
static DecodeStatus decodeBtBf(MCInst &MI, uint64_t V, uint64_t Address,
                               const MCDisassembler *Decoder) {
  if (V == 1)
    return addCond(MI, RL78CC::RL78CC_Z);
  if (V == 2)
    return addCond(MI, RL78CC::RL78CC_NZ);
  return MCDisassembler::Fail;
}

// saddr: FFE20H-FFF1FH from its low byte; sfr: FFF00H-FFFFFH; !addr16 of
// data: F0000H-FFFFFH.
static DecodeStatus decodeSaddr(MCInst &MI, uint64_t V, uint64_t Address,
                                const MCDisassembler *Decoder) {
  MI.addOperand(MCOperand::createImm((V < 0x20 ? 0xFFF00 : 0xFFE00) | V));
  return MCDisassembler::Success;
}
static DecodeStatus decodeSfr(MCInst &MI, uint64_t V, uint64_t Address,
                              const MCDisassembler *Decoder) {
  MI.addOperand(MCOperand::createImm(0xFFF00 | V));
  return MCDisassembler::Success;
}
static DecodeStatus decodeAddr16(MCInst &MI, uint64_t V, uint64_t Address,
                                 const MCDisassembler *Decoder) {
  MI.addOperand(MCOperand::createImm(0xF0000 | V));
  return MCDisassembler::Success;
}

// CALLT [addr5]: entry I is the word at 80H + 2 * I.
static DecodeStatus decodeCallt(MCInst &MI, uint64_t V, uint64_t Address,
                                const MCDisassembler *Decoder) {
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
