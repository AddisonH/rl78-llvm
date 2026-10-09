//===-- RL78AsmBackend.cpp - RL78 Assembler Backend ---------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/RL78AsmBackend.h"
#include "llvm/BinaryFormat/Dwarf.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Support/LEB128.h"
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

  // The address advance between two rows: a label difference that linker
  // relaxation may change. Emitted as DW_LNS_fixed_advance_pc (2 bytes) or
  // DW_LNE_set_address with a data fixup, which applyFixup turns into
  // relocations (SYM, SYM, OPsub, ABS16U/ABS32U).
  bool RL78AsmBackend::relaxDwarfLineAddr(MCFragment &F) const {
    int64_t LineDelta = F.getDwarfLineDelta();
    const MCExpr &AddrDelta = F.getDwarfAddrDelta();
    int64_t Value;
    if (AddrDelta.evaluateAsAbsolute(Value, *Asm))
      return false; // Not affected by relaxation: the default encoding.
    [[maybe_unused]] bool IsAbsolute =
        AddrDelta.evaluateKnownAbsolute(Value, *Asm);
    assert(IsAbsolute && "line address delta is not a label difference");

    SmallVector<char> Data;
    raw_svector_ostream OS(Data);
    // INT64_MAX marks a DW_LNE_end_sequence.
    if (LineDelta != INT64_MAX) {
      OS << uint8_t(dwarf::DW_LNS_advance_line);
      encodeSLEB128(LineDelta, OS);
    }
    // DW_LNS_fixed_advance_pc takes an unsigned half; relaxation only
    // shrinks code, so the current value bounds the final one.
    unsigned PCBytes;
    if (Value > 0xFFFF) {
      PCBytes = 4;
      OS << uint8_t(dwarf::DW_LNS_extended_op) << uint8_t(PCBytes + 1)
         << uint8_t(dwarf::DW_LNE_set_address);
    } else {
      PCBytes = 2;
      OS << uint8_t(dwarf::DW_LNS_fixed_advance_pc);
    }
    OS.write_zeros(PCBytes);
    unsigned Offset = OS.tell() - PCBytes;
    if (LineDelta == INT64_MAX)
      OS << uint8_t(dwarf::DW_LNS_extended_op) << uint8_t(1)
         << uint8_t(dwarf::DW_LNE_end_sequence);
    else
      OS << uint8_t(dwarf::DW_LNS_copy);

    const MCExpr *Fix = &AddrDelta;
    if (PCBytes == 4) {
      // DW_LNE_set_address takes the address itself: the end label.
      Fix = cast<MCBinaryExpr>(AddrDelta).getLHS();
    }
    F.setVarContents(Data);
    F.setVarFixups({MCFixup::create(Offset, Fix,
                                    MCFixup::getDataKindForSize(PCBytes))});
    return true;
  }

  // A CFA advance that relaxation may change: DW_CFA_advance_loc1/2/4 with a
  // data fixup (see relaxDwarfLineAddr).
  bool RL78AsmBackend::relaxDwarfCFA(MCFragment &F) const {
    const MCExpr &AddrDelta = F.getDwarfAddrDelta();
    int64_t Value;
    if (AddrDelta.evaluateAsAbsolute(Value, *Asm))
      return false;
    [[maybe_unused]] bool IsAbsolute =
        AddrDelta.evaluateKnownAbsolute(Value, *Asm);
    assert(IsAbsolute && "CFA advance is not a label difference");
    assert(getContext().getAsmInfo().getMinInstAlignment() == 1 &&
           "expected 1-byte alignment");

    SmallVector<char, 8> Data;
    raw_svector_ostream OS(Data);
    // Relaxation only shrinks code, so the current value bounds the size.
    unsigned Size = isUInt<8>(Value) ? 1 : isUInt<16>(Value) ? 2 : 4;
    OS << uint8_t(Size == 1   ? dwarf::DW_CFA_advance_loc1
                  : Size == 2 ? dwarf::DW_CFA_advance_loc2
                              : dwarf::DW_CFA_advance_loc4);
    OS.write_zeros(Size);
    F.setVarContents(Data);
    F.setVarFixups(
        {MCFixup::create(1, &AddrDelta, MCFixup::getDataKindForSize(Size))});
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
    if (!IsResolved && Target.getSubSym()) {
      // A label difference in a section with linker relaxation (DWARF
      // lengths and advances): computed by the linker on its stack.
      addDifferenceRelocs(F, Fixup, Target);
      return;
    }
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

  // A - B + C: SYM(A + C), SYM(B), OPsub, ABS8U/ABS16U/ABS32U.
  void addDifferenceRelocs(const MCFragment &F, const MCFixup &Fixup,
                           const MCValue &Target) {
    unsigned Store;
    switch (Fixup.getKind()) {
    case FK_Data_1:
      Store = RL78::fixup_RL78_ABS8U;
      break;
    case FK_Data_2:
      Store = RL78::fixup_RL78_ABS16U;
      break;
    case FK_Data_4:
      Store = RL78::fixup_RL78_ABS32U;
      break;
    default:
      getContext().reportError(Fixup.getLoc(),
                               "unsupported size for a label difference");
      return;
    }
    uint64_t Unused;
    auto Reloc = [&](unsigned Kind, const MCValue &V) {
      MCFixup R = MCFixup::create(Fixup.getOffset(), nullptr, Kind);
      Asm->getWriter().recordRelocation(F, R, V, Unused);
    };
    // A temporary label in a section without relaxation (e.g. the FDE's own
    // location for a pc-relative .eh_frame field) has no symbol table entry:
    // refer to it as the section start plus its (fixed) offset.
    auto Ref = [&](const MCSymbol *S, int64_t C) {
      if (S->isTemporary() && S->isInSection() &&
          !S->getSection().isLinkerRelaxable())
        return MCValue::get(S->getSection().getBeginSymbol(), nullptr,
                            Asm->getSymbolOffset(*S) + C);
      return MCValue::get(S, nullptr, C);
    };
    Reloc(RL78::fixup_RL78_SYM, Ref(Target.getAddSym(), Target.getConstant()));
    Reloc(RL78::fixup_RL78_SYM, Ref(Target.getSubSym(), 0));
    Reloc(RL78::fixup_RL78_OPsub, MCValue::get(nullptr));
    Reloc(Store, MCValue::get(nullptr));
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
