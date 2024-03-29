//===-- COM_slldiv.s - Implement _COM_slldiv ------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements _COM_slldiv for the compiler_rt library.
//
//===----------------------------------------------------------------------===//
//	_COM_slldiv
//
//	signed long long _COM_slldiv(signed long long x, signed long long y);
//
//	input:
//		x = [SP+4]
//		y = [SP+12]
//	output:
//		[AX]
//===----------------------------------------------------------------------===//
  #include "def.S"
  
  .PUBLIC __COM_slldiv
  .EXTERN __REL_lldiv
  .EXTERN __REL_llrev
  
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
__COM_slldiv:
  MOVW DE, AX
  MOVW HL, SP
  MOVW AX, [HL+12]
  OR A, X
  OR A, [HL+14]
  OR A, [HL+15]
  OR A, [HL+16]
  OR A, [HL+17]
  OR A, [HL+18]
  OR A, [HL+19]
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
  CLRB B
  MOV A, [SP+11]
  BF A.7, $.L2
  INC B
  MOVW AX, SP
  ADDW AX, #4
  MOVW HL, AX
  CALL !!__REL_llrev
.L2:
  MOVW AX, SP
  ADDW AX, #12
  MOVW HL, AX
  MOV A, [SP+19]
  BF A.7, $.L3
  INC B
  CALL !!__REL_llrev
.L3:
  MOVW AX, SP
  ADDW AX, #4
  XCHW AX, DE
  PUSH BC
  CALL !!__REL_lldiv
  POP BC
  DEC B
  SKNZ
  CALL !!__REL_llrev
  RET
.Lfunc_end1:
  .size __COM_slldiv, .Lfunc_end1-__COM_slldiv

  .weak  ___divdi3
  .type  ___divdi3,@function
  .set ___divdi3, __COM_slldiv

