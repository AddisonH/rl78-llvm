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

RL78ELFMCAsmInfo::RL78ELFMCAsmInfo(const Triple &TheTriple) {
  Data64bitsDirective = nullptr;
  ZeroDirective = "\t.skip\t";
  CommentString = ";";
  SupportsDebugInformation = true;

  ExceptionsType = ExceptionHandling::DwarfCFI;

  UsesELFSectionDirectiveForBSS = true;

  UseIntegratedAssembler = true;

  CodePointerSize = 4; // 32 bit considering far pointers.

  CalleeSaveStackSlotSize = 2; // A saved register is always 2 byte.

  HasRL78Expressions = true;

  AllowAtInName = true;

  MaxInstLength = 5; // mov (es:word[b], imm:8) and so on.
}
