//===----- RL78AsmBackend.h - RL78 Assembler Backend ----------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RL78_MCTARGETDESC_RL78ASMBACKEND_H
#define LLVM_LIB_TARGET_RL78_MCTARGETDESC_RL78ASMBACKEND_H

#include "MCTargetDesc/RL78FixupKinds.h"
#include "MCTargetDesc/RL78MCTargetDesc.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCSubtargetInfo.h"

namespace llvm {

class MCAssembler;
class MCObjectTargetWriter;
class raw_ostream;

class RL78AsmBackend : public MCAsmBackend {
protected:
  const Target &TheTarget;
  const MCSubtargetInfo &STI;
  bool ForceRelocs = false;

public:
  RL78AsmBackend(const Target &T, const MCSubtargetInfo &STI)
      : MCAsmBackend(llvm::endianness::little), TheTarget(T), STI(STI) {}

  void setForceRelocs() { ForceRelocs = true; }

  MCFixupKindInfo getFixupKindInfo(MCFixupKind Kind) const override;

  bool shouldForceRelocation(const MCFixup &Fixup) const;

  bool fixupNeedsRelaxationAdvanced(const MCFragment &, const MCFixup &Fixup,
                                    const MCValue &, uint64_t Value,
                                    bool Resolved) const override;

  bool mayNeedRelaxation(unsigned Opcode, ArrayRef<MCOperand> Operands,
                         const MCSubtargetInfo &STI) const override;

  void relaxInstruction(MCInst &Inst,
                        const MCSubtargetInfo &STI) const override;

  bool writeNopData(raw_ostream &OS, uint64_t Count,
                    const MCSubtargetInfo *STI) const override;

  // With linker relaxation, code offsets are only known at link time: line
  // and CFA advances become fixed-size fields filled by relocations.
  bool relaxDwarfLineAddr(MCFragment &F) const override;
  bool relaxDwarfCFA(MCFragment &F) const override;

  bool forceRelaxRelocs() const {
    return ForceRelocs || STI.hasFeature(RL78::FeatureRelax);
  }
};

}

#endif
