//===-- COM_uirem.s - Implement _COM_uirem --------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements _COM_uirem for the compiler_rt library.
//
//===----------------------------------------------------------------------===//
//	_COM_uirem
//
//	unsigned int _COM_uirem(unsigned int x, unsigned int y);
//
//	input:
//		x = AX
//		y = BC
//	output:
//		AX
//===----------------------------------------------------------------------===//
  #include "def.S"
  
  .globl __COM_uirem
  
  .text
__COM_uirem:
  MOVW DE, AX
  CLRW AX
  CMPW AX, BC
#if _RL78_S3
#else
  MOVW AX, DE
#endif
#ifdef __OPTIMIZE_SIZE__
  BZ $.L_ZERODIV
#else
  SKNZ
  BR $.L_ZERODIV
#endif
#if _RL78_S3
  MOVW AX, BC
  XCHW AX, DE
  DIVHU
  NOP                 ; TN-RL*-A025: not straight into the next instruction
#elif _XMULDIV
  PUSH PSW
  DI
  MOV !LOWW(MDUC), #0x080
  MOVW MDAL, AX
  MOVW AX, BC
  MOVW MDBL, AX
  CLRW AX
  MOVW MDAH, AX
  MOVW MDBH, AX
  MOV !LOWW(MDUC), #0x81
.L1:
  MOV A, !LOWW(MDUC)
  BT A.0, $.L1
  MOVW AX, !LOWW(MDCL)
  POP PSW
#else
  XCHW AX, BC
  MOVW DE, AX
  CLRW AX
  MOV L, #16
.L1:
  SHLW BC, 1
  ROLWC AX, 1
  CMPW AX, DE
  BC $.L2
  SUBW AX, DE
  INC C
.L2:
  DEC L
  BNZ $.L1
#endif
.L_ZERODIV:
#if _RL78_S3
  MOVW AX, DE
#else
#endif
  RET
.Lfunc_end1:
  .size __COM_uirem, .Lfunc_end1-__COM_uirem

  .weak ___umodhi3
  .type ___umodhi3,@function
  .set  ___umodhi3, __COM_uirem

