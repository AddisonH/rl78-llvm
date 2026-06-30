//===-- REL_delay_cycles_24bit.S - Implement __REL_delay_cycles_24bit -----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements __REL_delay_cycles_24bit for the compiler_rt library.
// To implement __delay_cycles builtin function.
//
//===----------------------------------------------------------------------===//

  .file   "REL_delay_cycles_24bit.S"
  .text
  .globl __REL_delay_cycles_24bit
  .type  __REL_delay_cycles_24bit,@function
__REL_delay_cycles_24bit:
  ; Input: 24-bit value in (A,X,C)
  ; This consumes cycles by loop.
  ; The number of iteration is (A - 128) * 256 * 256 + (X - 1) * 256 + (C - 1).
  ; Note 0 - 128 is regarded as 128.
  ; Consumes 10 cycles per loop iteration independently of whether
  ; sknz skips the next instruction or not.
  ; Compiler calculates these parameters from the actual cycles user specified.
.L:
  dec c      ; 1 cycle
  sknz       ; 1 cycle
  dec x      ; 1 cycle
  sknz       ; 1 cycle
  dec a      ; 1 cycle
  bt a.7, $.L; 3/5 cycle on not taken/taken
  ret        ; 7/6
.Lfunc_end1:
  .size __REL_delay_cycles_24bit, .Lfunc_end1-__REL_delay_cycles_24bit
