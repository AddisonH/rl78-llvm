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
#include "llvm/MC/MCFixupKindInfo.h"
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
      : MCAsmBackend(support::little, RL78::fixup_RL78_RELAX),
        TheTarget(T), STI(STI) {}

  unsigned getNumFixupKinds() const override {
    return RL78::NumTargetFixupKinds;
  }

  void setForceRelocs() { ForceRelocs = true; }

  const MCFixupKindInfo &getFixupKindInfo(MCFixupKind Kind) const override;

  bool shouldForceRelocation(const MCAssembler &Asm, const MCFixup &Fixup,
                             const MCValue &Target) override;

  bool fixupNeedsRelaxationAdvanced(const MCFixup &Fixup, bool Resolved,
                                    uint64_t Value,
                                    const MCRelaxableFragment *DF,
                                    const MCAsmLayout &Layout,
                                    const bool WasForced) const override;

  bool mayNeedRelaxation(const MCInst &Inst,
                         const MCSubtargetInfo &STI) const override;

  bool fixupNeedsRelaxation(const MCFixup &Fixup, uint64_t Value,
                            const MCRelaxableFragment *DF,
                            const MCAsmLayout &Layout) const override;

  void relaxInstruction(MCInst &Inst,
                        const MCSubtargetInfo &STI) const override;

  bool writeNopData(raw_ostream &OS, uint64_t Count,
                    const MCSubtargetInfo *STI) const override;

  bool forceRelaxRelocs() const {
    return ForceRelocs || STI.hasFeature(RL78::FeatureRelax);
  }
};

}

#endif
