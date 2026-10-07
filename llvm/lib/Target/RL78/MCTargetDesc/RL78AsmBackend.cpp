//===-- RL78AsmBackend.cpp - RL78 Assembler Backend ---------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/RL78AsmBackend.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/Support/EndianStream.h"
#include "RL78.h"
using namespace llvm;

static unsigned adjustFixupValue(unsigned Kind, int64_t Value, SMLoc Loc,
                                 bool ForceRelaxRelocs, MCContext &Ctx) {
  switch (Kind) {
  default:
    llvm_unreachable("Unknown fixup kind!");

  case FK_Data_1:
  case FK_Data_2:
  case FK_Data_4:
  case FK_Data_8:
    return Value;

  // These fixups are either resolved earlier and shouldn't appear here or will
  // be resolved with relocations, thus the value should be 0
  case RL78::fixup_RL78_OPsctsize:
  case RL78::fixup_RL78_OPscttop:
  case RL78::fixup_RL78_OPsub:
  case RL78::fixup_RL78_OPadd:
  case RL78::fixup_RL78_OPlowH:
  case RL78::fixup_RL78_OPlowL:
  case RL78::fixup_RL78_OPhighW:
  case RL78::fixup_RL78_OPlowW:
  case RL78::fixup_RL78_OPhighW_MIR:
  case RL78::fixup_RL78_OPlowW_MIR:
  case RL78::fixup_RL78_OPlowW_SMIR:
  case RL78::fixup_RL78_OPABSlowH:
  case RL78::fixup_RL78_OPABSlowL:
  case RL78::fixup_RL78_OPABShighW:
  case RL78::fixup_RL78_OPABSlowW:
  case RL78::fixup_RL78_ABS3U:
  case RL78::fixup_RL78_ABS8U:
  case RL78::fixup_RL78_ABS16U:
  case RL78::fixup_RL78_ABS16UW:
  case RL78::fixup_RL78_ABS20U:
  case RL78::fixup_RL78_ABS32U:
  case RL78::fixup_RL78_RELAX:
    if (Value)
      llvm_unreachable("Unknown fixup kind!");
    else
      return Value;

  case RL78::fixup_RL78_DIR3U:
    RL78ReportError(Value >= -4 && Value < 8,
                    "Instruction using illegal Value.", &Ctx, Loc);
    return Value;

  case RL78::fixup_RL78_DIR16U:
  case RL78::fixup_RL78_DIR16U_RAM:
  case RL78::fixup_RL78_DIR16UW_RAM:
    RL78ReportError(Value >= -32768 && Value <= 0xFFFF,
                    "Instruction using illegal Value.", &Ctx, Loc);
    return Value;

  case RL78::fixup_RL78_DIR20U:
    RL78ReportError(Value >= -524288 && Value <= 0xFFFFF,
                    "Instruction using illegal Value.", &Ctx, Loc);
    return Value;

  case RL78::fixup_RL78_DIR20U_16:
  case RL78::fixup_RL78_DIR20UW_16:
    RL78ReportError(Value >= -32768 && Value <= 0xFFFF,
                    "Instruction using illegal Value.", &Ctx, Loc);
    return Value;

  case RL78::fixup_RL78_SYM:
    return Value;

  case RL78::fixup_RL78_DIR8S_PCREL:
    RL78ReportError(Value >= -128 && Value <= 0xFF,
                    "Instruction using illegal Value.", &Ctx, Loc);
    return ForceRelaxRelocs ? Value : Value - 1;

  case RL78::fixup_RL78_DIR16S_PCREL:
    RL78ReportError(Value >= -32768 && Value <= 0xFFFF,
                    "Instruction using illegal Value.", &Ctx, Loc);
    return ForceRelaxRelocs ? Value : Value - 2;

  case RL78::fixup_RL78_DIR8U:
  case RL78::fixup_RL78_DIR8U_SAD:
  case RL78::fixup_RL78_DIR8UW_SAD:
    RL78ReportError(Value >= -128 && Value <= 0xFF,
                    "Instruction using illegal Value.", &Ctx, Loc);
    return Value;
    
  case RL78::fixup_RL78_DIR_CALLT:
    RL78ReportError(Value >= -16 && Value < 0x20,
                    "Instruction using illegal Value.", &Ctx, Loc);
	return Value;
  case RL78::fixup_RL78_DIR32U:
    RL78ReportError(Value >= INT32_MIN && Value <= UINT32_MAX,
                    "Instruction using illegal Value.", &Ctx, Loc);
    return Value;
  }
}

namespace llvm {

  MCFixupKindInfo RL78AsmBackend::getFixupKindInfo(MCFixupKind Kind) const {
    const static MCFixupKindInfo Infos[RL78::NumTargetFixupKinds] = {
        // Name                    Offset Bits  Flags.
        {"fixup_RL78_DIR8S_PCREL", 0, 8, 0},
        {"fixup_RL78_DIR16S_PCREL", 0, 16, 0},
        {"fixup_RL78_DIR3U", 0, 3, 0},
        {"fixup_RL78_DIR8U", 0, 8, 0},
        {"fixup_RL78_DIR8U_SAD", 0, 8, 0},
        {"fixup_RL78_DIR8UW_SAD", 0, 8, 0},
        {"fixup_RL78_DIR16U", 0, 16, 0},
        {"fixup_RL78_DIR16U_RAM", 0, 16, 0},
        {"fixup_RL78_DIR16UW_RAM", 0, 16, 0},
        {"fixup_RL78_DIR20U", 0, 20, 0},
        {"fixup_RL78_DIR20U_16", 0, 16, 0},
        {"fixup_RL78_DIR20UW_16", 0, 16, 0},
        {"fixup_RL78_DIR32U", 0, 32, 0},
        // The CALLT table index is split over non-contiguous bits of the
        // second byte (see the CALLT_addr5 encoder), which this table cannot
        // describe; the value is only ever resolved by the linker. With 5 bits
        // applyFixup wrote 5/8 = 0 bytes anyway, and -show-encoding asserted.
        {"fixup_RL78_DIR_CALLT", 0, 0, 0},
        {"fixup_RL78_SYM", 0, 0, 0},
        {"fixup_RL78_OPsctsize", 0, 0, 0},
        {"fixup_RL78_OPscttop", 0, 0, 0},
        {"fixup_RL78_OPsub", 0, 0, 0},
        {"fixup_RL78_OPadd", 0, 0, 0},
        {"fixup_RL78_OPlowH", 0, 0, 0},
        {"fixup_RL78_OPlowL", 0, 0, 0},
        {"fixup_RL78_OPhighW", 0, 0, 0},
        {"fixup_RL78_OPlowW", 0, 0, 0},
        {"fixup_RL78_OPhighW_MIR", 0, 0, 0},
        {"fixup_RL78_OPlowW_MIR", 0, 0, 0},
        {"fixup_RL78_OPlowW_SMIR", 0, 0, 0},
        {"fixup_RL78_OPABSlowH", 0, 0, 0},
        {"fixup_RL78_OPABSlowL", 0, 0, 0},
        {"fixup_RL78_OPABShighW", 0, 0, 0},
        {"fixup_RL78_OPABSlowW", 0, 0, 0},
        {"fixup_RL78_ABS3U", 0, 3, 0},
        {"fixup_RL78_ABS8U", 0, 8, 0},
        {"fixup_RL78_ABS16U", 0, 16, 0},
        {"fixup_RL78_ABS16UW", 0, 16, 0},
        {"fixup_RL78_ABS20U", 0, 20, 0},
        {"fixup_RL78_ABS32U", 0, 32, 0},
        {"fixup_RL78_RELAX", 0, 0, 0},
    };

    if (Kind < FirstTargetFixupKind)
      return MCAsmBackend::getFixupKindInfo(Kind);

    assert(unsigned(Kind - FirstTargetFixupKind) < RL78::NumTargetFixupKinds &&
           "Invalid kind!");
    return Infos[Kind - FirstTargetFixupKind];
  }

  /// Fixups that must always become relocations: the CC-RL operator stack
  /// (SYM/OP*/ABS*) and, with linker relaxation, the relaxable branches.
  bool RL78AsmBackend::shouldForceRelocation(const MCFixup &Fixup) const {
    switch ((RL78::Fixups)Fixup.getKind()) {
    default:
      return false;
    case RL78::fixup_RL78_SYM:
    case RL78::fixup_RL78_OPsub:
    case RL78::fixup_RL78_OPadd:
    case RL78::fixup_RL78_OPsctsize:
    case RL78::fixup_RL78_OPscttop:
    case RL78::fixup_RL78_OPlowH:
    case RL78::fixup_RL78_OPlowL:
    case RL78::fixup_RL78_OPhighW:
    case RL78::fixup_RL78_OPlowW:
    case RL78::fixup_RL78_OPhighW_MIR:
    case RL78::fixup_RL78_OPlowW_MIR:
    case RL78::fixup_RL78_OPlowW_SMIR:
    case RL78::fixup_RL78_OPABSlowH:
    case RL78::fixup_RL78_OPABSlowL:
    case RL78::fixup_RL78_OPABShighW:
    case RL78::fixup_RL78_OPABSlowW:
    case RL78::fixup_RL78_ABS3U:
    case RL78::fixup_RL78_ABS8U:
    case RL78::fixup_RL78_ABS16U:
    case RL78::fixup_RL78_ABS16UW:
    case RL78::fixup_RL78_ABS20U:
    case RL78::fixup_RL78_ABS32U:
      return true;
    case RL78::fixup_RL78_DIR16S_PCREL:
    case RL78::fixup_RL78_DIR8S_PCREL:
    case RL78::fixup_RL78_RELAX:
      return forceRelaxRelocs();
    }
  }

  // RL78 "relaxes" downwards: BR_rel16 is emitted and shrunk to BR_rel8 when
  // the displacement fits. As in LLVM 17 this ignores Resolved, so a branch
  // to a not-yet-resolved symbol is decided on the value computed so far.
  bool RL78AsmBackend::fixupNeedsRelaxationAdvanced(const MCFragment &,
                                                    const MCFixup &Fixup,
                                                    const MCValue &,
                                                    uint64_t Value,
                                                    bool Resolved) const {
    int64_t Offset = int64_t(Value);

    switch (Fixup.getKind()) {
    case RL78::fixup_RL78_DIR16S_PCREL:
      return (Offset > -128 && Offset < 127);
    default:
      return false;
    }
  }

  bool RL78AsmBackend::mayNeedRelaxation(unsigned Opcode,
                                         ArrayRef<MCOperand> Operands,
                                         const MCSubtargetInfo &STI) const {
    return Opcode == RL78::BR_rel16;
  }

  void RL78AsmBackend::relaxInstruction(MCInst &Inst,
                                        const MCSubtargetInfo &STI) const {
    MCInst Res;

    switch (Inst.getOpcode()) {
    case RL78::BR_rel16:
      Res.setOpcode(RL78::BR_rel8);
      break;
    default:
      return;
    }

    unsigned NumOperands = Inst.getNumOperands();
    for (unsigned i = 0; i < NumOperands; i++) {
      Res.addOperand(Inst.getOperand(i));
    }

    Inst = std::move(Res);
  }

  bool RL78AsmBackend::writeNopData(raw_ostream &OS, uint64_t Count,
                                    const MCSubtargetInfo *STI) const {

    for (uint64_t i = 0; i != Count; ++i)
      support::endian::write<uint8_t>(OS, 0x00, llvm::endianness::little);

    return true;
  }

} // end namespace llvm

namespace {

class ELFRL78AsmBackend : public llvm::RL78AsmBackend {

public:
  ELFRL78AsmBackend(const Target &T, const MCSubtargetInfo &STI)
      : RL78AsmBackend(T, STI) {}

  void applyFixup(const MCFragment &F, const MCFixup &Fixup,
                  const MCValue &Target, uint8_t *Data, uint64_t Value,
                  bool IsResolved) override {
    if (IsResolved && shouldForceRelocation(Fixup))
      IsResolved = false;
    maybeAddReloc(F, Fixup, Target, Value, IsResolved);
    if (mc::isRelocation(Fixup.getKind()))
      return;

    MCContext &Ctx = getContext();
    Value = adjustFixupValue(Fixup.getKind(), static_cast<int64_t>(Value),
                             Fixup.getLoc(), forceRelaxRelocs(), Ctx);
    if (!Value)
      return; // Doesn't change encoding.

    // For each byte of the fragment that the fixup touches, mask in the bits
    // from the fixup value. The Value has been "split up" into the
    // appropriate bitfields above. Data points at the fixup offset.
    for (unsigned i = 0, e = (getFixupKindInfo(Fixup.getKind()).TargetSize / 8);
         i != e; ++i)
      Data[i] |= uint8_t((Value >> (i * 8)) & 0xff);
  }

  std::unique_ptr<MCObjectTargetWriter>
  createObjectTargetWriter() const override {
    return createRL78ELFObjectWriter(false, ELF::ELFOSABI_NONE,
                                     forceRelaxRelocs());
  }
};

} // end anonymous namespace

MCAsmBackend *llvm::createRL78AsmBackend(const Target &T,
                                         const MCSubtargetInfo &STI,
                                         const MCRegisterInfo &MRI,
                                         const MCTargetOptions &Options) {
  return new ELFRL78AsmBackend(T, STI);
}
