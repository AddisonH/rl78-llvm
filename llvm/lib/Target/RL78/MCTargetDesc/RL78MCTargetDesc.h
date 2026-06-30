//===-- RL78MCTargetDesc.h - RL78 Target Descriptions ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file provides RL78 specific target descriptions.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RL78_MCTARGETDESC_RL78MCTARGETDESC_H
#define LLVM_LIB_TARGET_RL78_MCTARGETDESC_RL78MCTARGETDESC_H

#include <memory>

namespace llvm {
class MCAsmBackend;
class MCCodeEmitter;
class MCContext;
class MCInstrInfo;
class MCObjectTargetWriter;
class MCRegisterInfo;
class MCSubtargetInfo;
class MCTargetOptions;
class Target;
class Triple;
class StringRef;
class raw_pwrite_stream;
class raw_ostream;

/// SPII - This namespace holds all of the target specific flags that
/// instruction info tracks.
///
namespace SPII {
enum {
  Pseudo = (1 << 0),
  Load = (1 << 1),
  Store = (1 << 2),
  DelaySlot = (1 << 3)
};

///// Target Operand Flag enum.
enum TOF { NONE, MO_OUTLINE_SP, MO_NO_OUTLINE_SP, TOF_LAST };

} // end namespace SPII

MCCodeEmitter *createRL78MCCodeEmitter(const MCInstrInfo &MCII,
                                       MCContext &Ctx);
MCAsmBackend *createRL78AsmBackend(const Target &T, const MCSubtargetInfo &STI,
                                   const MCRegisterInfo &MRI,
                                   const MCTargetOptions &Options);
std::unique_ptr<MCObjectTargetWriter> createRL78ELFObjectWriter(bool Is64Bit,
                                                                uint8_t OSABI,
                                                                bool ForceRelaxRelocs);
} // end namespace llvm

// Defines symbolic names for RL78 registers.  This defines a mapping from
// register name to register number.
//
#define GET_REGINFO_ENUM
#include "RL78GenRegisterInfo.inc"

// Defines symbolic names for the RL78 instructions.
//
#define GET_INSTRINFO_ENUM
#include "RL78GenInstrInfo.inc"

#define GET_SUBTARGETINFO_ENUM
#include "RL78GenSubtargetInfo.inc"

#endif
