//===- RL78MCAsmInfo.cpp - RL78 asm properties --------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the declarations of the RL78MCAsmInfo properties.
//
//===----------------------------------------------------------------------===//

#include "RL78MCAsmInfo.h"

using namespace llvm;

void RL78ELFMCAsmInfo::anchor() {}

RL78ELFMCAsmInfo::RL78ELFMCAsmInfo(const Triple &TheTriple,
                                   const MCTargetOptions &Options)
    : MCAsmInfoELF(Options) {
  Data64bitsDirective = nullptr;
  ZeroDirective = "\t.skip\t";
  CommentString = ";";
  SupportsDebugInformation = true;

  ExceptionsType = ExceptionHandling::DwarfCFI;

  UsesELFSectionDirectiveForBSS = true;

  UseIntegratedAssembler = true;

  CodePointerSize = 4; // 32 bit considering far pointers.

  CalleeSaveStackSlotSize = 2; // A saved register is always 2 byte.

  // "0xFFE30.3" is bit 3 of an address, not a hexadecimal float.
  AllowHexFloatLiterals = false;
  // Linker relaxation: label differences use the CC-RL operator relocations,
  // which have no ULEB128 form.
  CanRelocateULEB128Differences = false;
  UseNamesOnBlockLabels = true;

  // Keep LLVM 17's `.set sym, value` form (upstream now defaults to `sym = value`).
  UsesSetToEquateSymbol = true;

  AllowAtInName = true;

  MaxInstLength = 5; // mov (es:word[b], imm:8) and so on.
}
