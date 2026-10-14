//===-- RL78MCCodeEmitter.cpp - Convert RL78 code to machine code -------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the RL78MCCodeEmitter class.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78MCExpr.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/Support/EndianStream.h"
#include "llvm/Support/SourceMgr.h"

using namespace llvm;

#define DEBUG_TYPE "mccodeemitter"

STATISTIC(MCNumEmitted, "Number of MC instructions emitted");

namespace {

class RL78MCCodeEmitter : public MCCodeEmitter {
  const MCInstrInfo &MCII;
  MCContext &Ctx;

public:
  RL78MCCodeEmitter(const MCInstrInfo &mcii, MCContext &ctx)
      : MCII(mcii), Ctx(ctx) {}
  RL78MCCodeEmitter(const RL78MCCodeEmitter &) = delete;
  RL78MCCodeEmitter &operator=(const RL78MCCodeEmitter &) = delete;
  ~RL78MCCodeEmitter() override = default;

  void encodeInstruction(const MCInst &MI, SmallVectorImpl<char> &CB,
                         SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const override;

  // getBinaryCodeForInstr - TableGen'erated function for getting the
  // binary encoding for an instruction.
  uint64_t getBinaryCodeForInstr(const MCInst &MI,
                                 SmallVectorImpl<MCFixup> &Fixups,
                                 const MCSubtargetInfo &STI) const;

  /// getMachineOpValue - Return binary encoding of operand. If the machine
  /// operand requires relocation, record the relocation and return zero.
  unsigned getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;

  unsigned
  getTargetOpValue(const MCInst &MI, unsigned OpNo, uint32_t offset,
                   SmallVectorImpl<MCFixup> &Fixups, const MCSubtargetInfo &STI,
                   MCFixupKind fixup1) const;


  // TableGen'erated: the bit position of operand OpNum's field in Inst.
  uint32_t getOperandBitOffset(const MCInst &MI, unsigned OpNum,
                               const MCSubtargetInfo &STI) const;

  // Operands of the hardware instructions (RL78InstrISA.td). Field is the
  // operand the encoding field belongs to (the first sub-operand of a
  // memory operand), Val the one holding the value or expression.
  unsigned getFieldValue(const MCInst &MI, unsigned Field, unsigned Val,
                         SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI, unsigned Kind) const;
#define RL78_OPERAND_ENCODER(NAME)                                             \
  unsigned NAME(const MCInst &MI, unsigned OpNo,                               \
                SmallVectorImpl<MCFixup> &Fixups, const MCSubtargetInfo &STI)   \
      const;
  RL78_OPERAND_ENCODER(getImm8OpValue)
  RL78_OPERAND_ENCODER(getImm16OpValue)
  RL78_OPERAND_ENCODER(getSaddrOpValue)
  RL78_OPERAND_ENCODER(getSaddrpOpValue)
  RL78_OPERAND_ENCODER(getSfrOpValue)
  RL78_OPERAND_ENCODER(getAddr16OpValue)
  RL78_OPERAND_ENCODER(getAddr16wOpValue)
  RL78_OPERAND_ENCODER(getFarAddr16OpValue)
  RL78_OPERAND_ENCODER(getFarAddr16wOpValue)
  RL78_OPERAND_ENCODER(getIsCOpValue)
  RL78_OPERAND_ENCODER(getIsBOpValue)
  RL78_OPERAND_ENCODER(getIsHLOpValue)
  RL78_OPERAND_ENCODER(getIsDEOpValue)
  RL78_OPERAND_ENCODER(getDEHLDispOpValue)
  RL78_OPERAND_ENCODER(getLowSaddrOpcode)
  RL78_OPERAND_ENCODER(getLowAbsOpcode)
  RL78_OPERAND_ENCODER(getRpSaddrpOpcode)
  RL78_OPERAND_ENCODER(getRpAbsOpcode)
  RL78_OPERAND_ENCODER(getShlRegOpValue)
  RL78_OPERAND_ENCODER(getRel8OpValue)
  RL78_OPERAND_ENCODER(getRel16OpValue)
  RL78_OPERAND_ENCODER(getCode16OpValue)
  RL78_OPERAND_ENCODER(getCode20OpValue)
  RL78_OPERAND_ENCODER(getCalltOpValue)
  RL78_OPERAND_ENCODER(getBccOpValue)
  RL78_OPERAND_ENCODER(getHccOpValue)
  RL78_OPERAND_ENCODER(getBtBfOpValue)
  RL78_OPERAND_ENCODER(getMachineOpValueImm)
  RL78_OPERAND_ENCODER(getBitOpValue)
  RL78_OPERAND_ENCODER(getShift8OpValue)
  RL78_OPERAND_ENCODER(getShift16OpValue)
  RL78_OPERAND_ENCODER(getRBOpValue)
  RL78_OPERAND_ENCODER(getShlwRegOpValue)
#undef RL78_OPERAND_ENCODER
};

} // end anonymous namespace

void RL78MCCodeEmitter::encodeInstruction(const MCInst &MI,
                                          SmallVectorImpl<char> &CB,
                                          SmallVectorImpl<MCFixup> &Fixups,
                                          const MCSubtargetInfo &STI) const {
  // Only hardware instructions (RL78InstrISA.td) reach the encoder; code
  // generation's own definitions are lowered to them (RL78LowerToHardware).
  // Bits holds the bytes in order, the first one in the low bits.
  const MCInstrDesc &Desc = MCII.get(MI.getOpcode());
  if (!(Desc.TSFlags & RL78II::Hardware))
    reportFatalInternalError(Twine("RL78: not a hardware instruction: ") +
                             MCII.getName(MI.getOpcode()));
  uint64_t Bits = getBinaryCodeForInstr(MI, Fixups, STI);
  for (unsigned I = 0, Size = Desc.getSize(); I < Size; ++I)
    CB.push_back(char(Bits >> (8 * I)));
  ++MCNumEmitted;
}

unsigned
RL78MCCodeEmitter::getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                                     SmallVectorImpl<MCFixup> &Fixups,
                                     const MCSubtargetInfo &STI) const {
  if (MO.isReg())
    return Ctx.getRegisterInfo()->getEncodingValue(MO.getReg());

  if (MO.isImm())
    return MO.getImm();

  llvm_unreachable("Unhandled expression!");
  return 0;
}

unsigned RL78MCCodeEmitter::getTargetOpValue(const MCInst &MI, unsigned OpNo,
                                             uint32_t offset,
                                             SmallVectorImpl<MCFixup> &Fixups,
                                             const MCSubtargetInfo &STI,
                                             MCFixupKind fixup1) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  if (MO.isImm()) {
    int64_t immediateValue = MO.getImm();
    switch (static_cast<RL78::Fixups>(fixup1)) {
    case RL78::fixup_RL78_DIR8S_PCREL:
      RL78ReportError(immediateValue >= -128 && immediateValue <= 127,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR16S_PCREL:
      RL78ReportError(immediateValue >= -32768 && immediateValue <= 32767,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR3U:
      RL78ReportError(immediateValue >= 0x0 && immediateValue <= 0x7,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR8U:
      RL78ReportError(immediateValue >= -128 && immediateValue <= 255,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR8U_SAD:
      RL78ReportError(immediateValue >= 0xFFE20 && immediateValue <= 0XFFF1F,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR8UW_SAD:
      RL78ReportError(immediateValue >= 0xFFE20 && immediateValue <= 0xFFFFF &&
                          immediateValue % 2 == 0,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR16U:
      RL78ReportError(immediateValue >= -32768 && immediateValue <= 65536,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR16U_RAM:
    case RL78::fixup_RL78_DIR16UW_RAM:
      RL78ReportError(immediateValue >= -65536 && immediateValue <= 0xFFFFF,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR20U:
      RL78ReportError(immediateValue >= 0x00000 && immediateValue <= 0xFFFFF,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR20U_16:
    case RL78::fixup_RL78_DIR20UW_16:
      RL78ReportError(immediateValue >= -32768 && immediateValue <= 65536,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR32U:
      RL78ReportError(immediateValue >= INT32_MIN && immediateValue <= UINT32_MAX,
                      "Instruction using illegal operand");
      break;
    case RL78::fixup_RL78_DIR_CALLT:
      RL78ReportError(immediateValue >= 0x80 && immediateValue <= 0xBF &&
                          immediateValue % 2 == 0,
                      "Instruction using illegal operand");
      break;
    default:
      break;
    }
  }

  if (MO.isReg() || MO.isImm())
    return getMachineOpValue(MI, MO, Fixups, STI);

  unsigned valueSize;
  // Deduce the expected expression's result value size.
  const auto rl78Fixup = static_cast<RL78::Fixups>(fixup1);
  switch (rl78Fixup)
  {
  default: 
      // The missing fixups are doing pushes/pops on the relocation "stack",
      // so they should not appear as last, value producing fixups.
      llvm_unreachable("Unhandled fixup!");
      break;
  case RL78::fixup_RL78_DIR3U:
      valueSize = 3;
      break;
  case RL78::fixup_RL78_DIR8S_PCREL:
  case RL78::fixup_RL78_DIR8U:
  case RL78::fixup_RL78_DIR8U_SAD:
  case RL78::fixup_RL78_DIR8UW_SAD:
  case RL78::fixup_RL78_ABS8U:
  case RL78::fixup_RL78_DIR_CALLT:
      valueSize = 8;
      break;
  case RL78::fixup_RL78_DIR16S_PCREL:
  case RL78::fixup_RL78_DIR16U:
  case RL78::fixup_RL78_DIR16U_RAM:
  case RL78::fixup_RL78_DIR16UW_RAM:
  case RL78::fixup_RL78_DIR20U_16:
  case RL78::fixup_RL78_DIR20UW_16:
  case RL78::fixup_RL78_ABS16U:
  case RL78::fixup_RL78_ABS16UW:
      valueSize = 16;
      break;
  case RL78::fixup_RL78_DIR20U:
      valueSize = 24;
      break;
  case RL78::fixup_RL78_ABS32U:
  case RL78::fixup_RL78_DIR32U:
      valueSize = 32;
      break;
  }

  if (MO.isExpr() &&
      fixup1 != static_cast<MCFixupKind>(RL78::fixup_RL78_DIR_CALLT)) {
    RL78MCExpr::createFixupsForExpression(MO.getExpr(), offset, valueSize,
                                          Fixups, true, fixup1, Ctx, MI.getLoc());
  } else {
    Fixups.push_back(RL78::createFixup(offset, MO.getExpr(), fixup1));
  }

  // Ensure an R_RL78_RELAX relocation will be emitted if linker relaxation
  // is enabled and the current fixup will result in a relocation that may
  // be relaxed.
  if (STI.hasFeature(RL78::FeatureRelax)) {
    switch (rl78Fixup) {
    case RL78::fixup_RL78_DIR20U:
    case RL78::fixup_RL78_DIR16U:
    case RL78::fixup_RL78_DIR16S_PCREL: {
      // Marking the fixup linker-relaxable keeps label differences in the
      // section symbolic: the backend emits them as relocations (DWARF
      // lengths, line and CFA advances) so they follow relaxation.
      MCFixup Relax = RL78::createFixup(offset, MCConstantExpr::create(0, Ctx),
                                        RL78::fixup_RL78_RELAX);
      Relax.setLinkerRelaxable();
      Fixups.push_back(Relax);
      break;
    }
    default:
      break;
    }
  }

  return 0;
}

unsigned RL78MCCodeEmitter::getFieldValue(const MCInst &MI, unsigned Field,
                                          unsigned Val,
                                          SmallVectorImpl<MCFixup> &Fixups,
                                          const MCSubtargetInfo &STI,
                                          unsigned Kind) const {
  // Inst keeps byte I in bits 8*I..8*I+7, so a field's byte offset is its
  // bit offset over 8.
  uint32_t Offset = getOperandBitOffset(MI, Field, STI) / 8;
  return getTargetOpValue(MI, Val, Offset, Fixups, STI, MCFixupKind(Kind));
}

#define RL78_FIXUP_ENCODER(NAME, KIND)                                          \
  unsigned RL78MCCodeEmitter::NAME(const MCInst &MI, unsigned OpNo,            \
                                   SmallVectorImpl<MCFixup> &Fixups,           \
                                   const MCSubtargetInfo &STI) const {         \
    return getFieldValue(MI, OpNo, OpNo, Fixups, STI, RL78::KIND);             \
  }
// #byte and [rp+byte] displacements; #word.
RL78_FIXUP_ENCODER(getImm8OpValue, fixup_RL78_DIR8U)
RL78_FIXUP_ENCODER(getImm16OpValue, fixup_RL78_DIR16U)
// saddr, saddrp: the linker checks the address is in FFE20H-FFF1FH.
RL78_FIXUP_ENCODER(getSaddrOpValue, fixup_RL78_DIR8U_SAD)
RL78_FIXUP_ENCODER(getSaddrpOpValue, fixup_RL78_DIR8UW_SAD)
// !addr16 data: the linker checks the address is in F0000H-FFFFFH.
RL78_FIXUP_ENCODER(getAddr16OpValue, fixup_RL78_DIR16U_RAM)
RL78_FIXUP_ENCODER(getAddr16wOpValue, fixup_RL78_DIR16UW_RAM)
// ES:!addr16: ES supplies bits 19-16, any 20-bit address will do.
RL78_FIXUP_ENCODER(getFarAddr16OpValue, fixup_RL78_DIR20U_16)
RL78_FIXUP_ENCODER(getFarAddr16wOpValue, fixup_RL78_DIR20UW_16)
// Branch displacements ($addr20, $!addr20) and code addresses.
RL78_FIXUP_ENCODER(getRel8OpValue, fixup_RL78_DIR8S_PCREL)
RL78_FIXUP_ENCODER(getRel16OpValue, fixup_RL78_DIR16S_PCREL)
RL78_FIXUP_ENCODER(getCode16OpValue, fixup_RL78_DIR16U)
RL78_FIXUP_ENCODER(getCode20OpValue, fixup_RL78_DIR20U)
#undef RL78_FIXUP_ENCODER

// CALLT [addr5]: the index of the table entry, (addr5 - 80H) / 2. For a
// symbol the linker writes the whole opcode byte (R_RL78_DIR_CALLT).
unsigned RL78MCCodeEmitter::getCalltOpValue(const MCInst &MI, unsigned OpNo,
                                            SmallVectorImpl<MCFixup> &Fixups,
                                            const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  if (MO.isImm()) {
    int64_t Addr = MO.getImm();
    RL78ReportError(Addr >= 0x80 && Addr <= 0xBE && Addr % 2 == 0,
                    "CALLT table entry must be an even address in 80H-BEH");
    return (Addr - 0x80) / 2;
  }
  uint32_t Offset = getOperandBitOffset(MI, OpNo, STI) / 8;
  Fixups.push_back(
      RL78::createFixup(Offset, MO.getExpr(), RL78::fixup_RL78_DIR_CALLT));
  return 0;
}

// BC, BZ, BNC, BNZ: DC, DD, DE, DF.
unsigned RL78MCCodeEmitter::getBccOpValue(const MCInst &MI, unsigned OpNo,
                                          SmallVectorImpl<MCFixup> &Fixups,
                                          const MCSubtargetInfo &STI) const {
  switch (MI.getOperand(OpNo).getImm()) {
  case RL78CC::RL78CC_C:
    return 0;
  case RL78CC::RL78CC_Z:
    return 1;
  case RL78CC::RL78CC_NC:
    return 2;
  case RL78CC::RL78CC_NZ:
    return 3;
  }
  llvm_unreachable("not a C/NC/Z/NZ condition");
}

// BH/BNH, SKH/SKNH.
unsigned RL78MCCodeEmitter::getHccOpValue(const MCInst &MI, unsigned OpNo,
                                          SmallVectorImpl<MCFixup> &Fixups,
                                          const MCSubtargetInfo &STI) const {
  return MI.getOperand(OpNo).getImm() == RL78CC::RL78CC_NH;
}

// BT (Z, bit set) 01, BF (NZ) 10.
unsigned RL78MCCodeEmitter::getBtBfOpValue(const MCInst &MI, unsigned OpNo,
                                           SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
  return MI.getOperand(OpNo).getImm() == RL78CC::RL78CC_Z ? 1 : 2;
}

// Small fields the encoding would otherwise silently truncate.
static unsigned checkedField(const MCOperand &MO, int64_t Lo, int64_t Hi,
                             StringRef Message) {
  RL78ReportError(MO.isImm() && MO.getImm() >= Lo && MO.getImm() <= Hi,
                  Message);
  return MO.getImm();
}

// A bit number, 0-7.
unsigned RL78MCCodeEmitter::getBitOpValue(const MCInst &MI, unsigned OpNo,
                                          SmallVectorImpl<MCFixup> &Fixups,
                                          const MCSubtargetInfo &STI) const {
  return checkedField(MI.getOperand(OpNo), 0, 7,
                      "Instruction using operand outside of range 0-7.");
}

// A shift count, 1-7 or 1-15.
unsigned RL78MCCodeEmitter::getShift8OpValue(const MCInst &MI, unsigned OpNo,
                                             SmallVectorImpl<MCFixup> &Fixups,
                                             const MCSubtargetInfo &STI) const {
  return checkedField(MI.getOperand(OpNo), 1, 7,
                      "Instruction using operand outside of range 1-7.");
}
unsigned
RL78MCCodeEmitter::getShift16OpValue(const MCInst &MI, unsigned OpNo,
                                     SmallVectorImpl<MCFixup> &Fixups,
                                     const MCSubtargetInfo &STI) const {
  return checkedField(MI.getOperand(OpNo), 1, 15,
                      "Instruction using operand outside of range 1-15.");
}

// SEL RBn: a register bank, 0-3.
unsigned RL78MCCodeEmitter::getRBOpValue(const MCInst &MI, unsigned OpNo,
                                         SmallVectorImpl<MCFixup> &Fixups,
                                         const MCSubtargetInfo &STI) const {
  return checkedField(MI.getOperand(OpNo), 0, 3,
                      "Instruction using operand outside of range 0-3.");
}

unsigned
RL78MCCodeEmitter::getMachineOpValueImm(const MCInst &MI, unsigned OpNo,
                                        SmallVectorImpl<MCFixup> &Fixups,
                                        const MCSubtargetInfo &STI) const {
  return MI.getOperand(OpNo).getImm();
}

// sfr, sfrp: a fixed address in FFF00H-FFFFFH; the low byte is encoded.
unsigned RL78MCCodeEmitter::getSfrOpValue(const MCInst &MI, unsigned OpNo,
                                          SmallVectorImpl<MCFixup> &Fixups,
                                          const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  int64_t Value;
  if (MO.isImm())
    Value = MO.getImm();
  else if (!MO.getExpr()->evaluateAsAbsolute(Value))
    reportFatalUsageError("sfr operand must be an absolute address");
  RL78ReportError((Value & 0xFFFFF) >= 0xFFF00, "sfr operand not in range");
  return Value & 0xFF;
}

static MCRegister reg(const MCInst &MI, unsigned OpNo) {
  return MI.getOperand(OpNo).getReg();
}

// [HL+B]/[HL+C].
unsigned RL78MCCodeEmitter::getIsCOpValue(const MCInst &MI, unsigned OpNo,
                                          SmallVectorImpl<MCFixup> &Fixups,
                                          const MCSubtargetInfo &STI) const {
  return reg(MI, OpNo) == RL78::R2;
}
unsigned RL78MCCodeEmitter::getIsBOpValue(const MCInst &MI, unsigned OpNo,
                                          SmallVectorImpl<MCFixup> &Fixups,
                                          const MCSubtargetInfo &STI) const {
  return reg(MI, OpNo) == RL78::R3;
}

// [DE]/[HL], [DE+byte]/[HL+byte].
unsigned RL78MCCodeEmitter::getIsHLOpValue(const MCInst &MI, unsigned OpNo,
                                           SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
  return reg(MI, OpNo) == RL78::RP6;
}
unsigned RL78MCCodeEmitter::getIsDEOpValue(const MCInst &MI, unsigned OpNo,
                                           SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
  return reg(MI, OpNo) == RL78::RP4;
}
unsigned
RL78MCCodeEmitter::getDEHLDispOpValue(const MCInst &MI, unsigned OpNo,
                                      SmallVectorImpl<MCFixup> &Fixups,
                                      const MCSubtargetInfo &STI) const {
  return reg(MI, OpNo) == RL78::RP6 ? 2 : 1;
}

// MOV r, saddr and MOV r, !addr16 (r: X, A, C, B); MOVW rp, saddrp and
// MOVW rp, !addr16: the opcode byte.
unsigned RL78MCCodeEmitter::getLowSaddrOpcode(const MCInst &MI, unsigned OpNo,
                                              SmallVectorImpl<MCFixup> &Fixups,
                                              const MCSubtargetInfo &STI) const {
  switch (reg(MI, OpNo)) {
  case RL78::R0:
    return 0xD8;
  case RL78::R1:
    return 0x8D;
  case RL78::R2:
    return 0xF8;
  case RL78::R3:
    return 0xE8;
  }
  llvm_unreachable("MOV r, saddr takes X, A, C or B");
}
unsigned RL78MCCodeEmitter::getLowAbsOpcode(const MCInst &MI, unsigned OpNo,
                                            SmallVectorImpl<MCFixup> &Fixups,
                                            const MCSubtargetInfo &STI) const {
  switch (reg(MI, OpNo)) {
  case RL78::R0:
    return 0xD9;
  case RL78::R1:
    return 0x8F;
  case RL78::R2:
    return 0xF9;
  case RL78::R3:
    return 0xE9;
  }
  llvm_unreachable("MOV r, !addr16 takes X, A, C or B");
}
unsigned RL78MCCodeEmitter::getRpSaddrpOpcode(const MCInst &MI, unsigned OpNo,
                                              SmallVectorImpl<MCFixup> &Fixups,
                                              const MCSubtargetInfo &STI) const {
  switch (reg(MI, OpNo)) {
  case RL78::RP0:
    return 0xAD;
  case RL78::RP2:
    return 0xDA;
  case RL78::RP4:
    return 0xEA;
  case RL78::RP6:
    return 0xFA;
  }
  llvm_unreachable("MOVW rp, saddrp takes a register pair");
}
unsigned RL78MCCodeEmitter::getRpAbsOpcode(const MCInst &MI, unsigned OpNo,
                                           SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
  switch (reg(MI, OpNo)) {
  case RL78::RP0:
    return 0xAF;
  case RL78::RP2:
    return 0xDB;
  case RL78::RP4:
    return 0xEB;
  case RL78::RP6:
    return 0xFB;
  }
  llvm_unreachable("MOVW rp, !addr16 takes a register pair");
}

// SHL A/B/C: 9, 8, 7 in the low nibble.
unsigned RL78MCCodeEmitter::getShlRegOpValue(const MCInst &MI, unsigned OpNo,
                                             SmallVectorImpl<MCFixup> &Fixups,
                                             const MCSubtargetInfo &STI) const {
  switch (reg(MI, OpNo)) {
  case RL78::R1:
    return 9;
  case RL78::R3:
    return 8;
  case RL78::R2:
    return 7;
  }
  llvm_unreachable("SHL takes A, B or C");
}

// SHLW AX/BC: D, C in the low nibble.
unsigned
RL78MCCodeEmitter::getShlwRegOpValue(const MCInst &MI, unsigned OpNo,
                                     SmallVectorImpl<MCFixup> &Fixups,
                                     const MCSubtargetInfo &STI) const {
  return reg(MI, OpNo) == RL78::RP0 ? 0xD : 0xC;
}

MCCodeEmitter *llvm::createRL78MCCodeEmitter(const MCInstrInfo &MCII,
                                             MCContext &Ctx) {
  return new RL78MCCodeEmitter(MCII, Ctx);
}

#define GET_OPERAND_BIT_OFFSET
#include "RL78GenMCCodeEmitter.inc"
