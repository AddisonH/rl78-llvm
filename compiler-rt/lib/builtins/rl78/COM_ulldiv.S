//===-- COM_ulldiv.s - Implement _COM_ulldiv ------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements _COM_ulldiv for the compiler_rt library.
//
//===----------------------------------------------------------------------===//
//	_COM_ulldiv
//
//	unsigned long long
//	_COM_ulldiv(unsigned long long x, unsigned long long y);
//
//	input:
//		x = [SP+4]
//		y = [SP+12]
//	output:
//		[AX]
//===----------------------------------------------------------------------===//
  #include "def.S"
  
  .PUBLIC __COM_ulldiv
  .EXTERN __REL_lldiv
  
  .text
#ifndef __OPTIMIZE_SIZE__
.L_ZERODIV:
  DECW AX
  MOVW [DE], AX
  MOVW [DE+2], AX
  MOVW [DE+4], AX
  MOVW [DE+6], AX
  RET
#endif

__COM_ulldiv:
  MOVW DE, AX
  MOVW AX, SP
  ADDW AX, #12
  MOVW HL, AX
  MOVW AX, [HL]
  OR A, X
  OR A, [HL+2]
  OR A, [HL+3]
  OR A, [HL+4]
  OR A, [HL+5]
  OR A, [HL+6]
  OR A, [HL+7]
#ifdef __OPTIMIZE_SIZE__
  BNZ $.L1
  DECW	AX
  MOVW	[DE],AX		; ret = -1
  MOVW	[DE+2],AX
  MOVW	[DE+4],AX
  MOVW	[DE+6],AX
  RET
#else
  SKNZ
  BR $.L_ZERODIV
#endif
.L1:
  MOVW AX, HL
  SUBW AX, #8
  XCHW AX, DE
  BR !!__REL_lldiv
.Lfunc_end1:
  .size __COM_ulldiv, .Lfunc_end1-__COM_ulldiv

  .weak ___udivdi3
  .type ___udivdi3,@function
  .set  ___udivdi3, __COM_ulldiv

