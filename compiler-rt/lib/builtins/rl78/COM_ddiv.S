//===-- COM_ddiv.s - Implement _COM_ddiv ----------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements _COM_ddiv for the compiler_rt library.
//
//===----------------------------------------------------------------------===//
//	_COM_ddiv
//
//	double _COM_ddiv(double x, double y);
//
//	input:
//		x = [SP+4]
//		y = [SP+12]
//	output:
//		[AX] ([A:DE] for far data)
//===----------------------------------------------------------------------===//
  #include "def.S"
  #include "REL_d_pack.h"

#ifdef __FAR_DATA__
#define __COM_ddiv  __COM_ddiv_nd
#endif

  .globl __COM_ddiv
  .extern __COM_mului
  .extern __REL_d_check
  .extern __REL_d_inf
  .extern __REL_d_pack

//	The quotient of the two 53-bit mantissas is taken to 64 bits, of which
//	the top one is set: its top 53 bits are the result; the bits below them,
//	with the remainder collected in the lowest one, round it to nearest
//	even.
//
//	With DIVWU and MULHU, or with the multiplier and divider unit, it is
//	long division in base 65536 (Knuth, algorithm D): both mantissas go up
//	so that the top bit of the divisor is bit 63 and the dividend is below
//	the divisor; each of the four digits of the quotient comes from the top
//	two digits of the remainder and the top digit of the divisor, at most 2
//	too high; the multiple of the divisor is subtracted and added back while
//	the result is negative. The other cores subtract and shift for each bit.
//
//	The frame, from SP, once the work area is there:
//	   0  U, eight words: the dividend in the upper four over four words of
//	      zeros; the remainder moves down a word a digit, and the digits of
//	      the quotient take the words it leaves
//	  16  the exponent
//	  19  bit 7: the sign
//	  20  where the result goes
//	  26  x (22: the return address)
//	  34  y
#define F_EXP   16
#define F_SIGN  19
#define F_RES   20
#define F_X     26
#define F_Y     34
#define F_SIZE  22

#if _RL78_S3
#define DIGITS 1
#define MUL16 mulhu
#elif defined(__MDA_ENABLED__)
#define DIGITS 1
#define MUL16 call !!__COM_mului
#else
#define DIGITS 0
#endif

  .text

#if DIGITS
  ; Four words from \src to \dst, both from SP, up by \n bits, \n above 8.
  ; From the top word down, so that \dst may be \src.
.macro SHIFT_UP src, dst, n
  movw  ax,[sp+\src+4]
  shrw  ax,16-\n
  movw  bc,ax
  movw  ax,[sp+\src+6]
  shlw  ax,\n
  addw  ax,bc
  movw  [sp+\dst+6],ax
  movw  ax,[sp+\src+2]
  shrw  ax,16-\n
  movw  bc,ax
  movw  ax,[sp+\src+4]
  shlw  ax,\n
  addw  ax,bc
  movw  [sp+\dst+4],ax
  movw  ax,[sp+\src]
  shrw  ax,16-\n
  movw  bc,ax
  movw  ax,[sp+\src+2]
  shlw  ax,\n
  addw  ax,bc
  movw  [sp+\dst+2],ax
  movw  ax,[sp+\src]
  shlw  ax,\n
  movw  [sp+\dst],ax
.endm

  ; BC:AX / DE to AX; the quotient is below 65536. HL stays.
.macro DIV32
#if _RL78_S3
  push  hl
  movw  hl,#0
  divwu
  nop                       ; TN-RL*-A025: not straight into the next instruction
  pop   hl
#else
  call  $!.L_div32
#endif
.endm

#endif

  .type  __COM_ddiv,@function
__COM_ddiv:
  push  ax
  movw  hl,sp               ; x: [HL+6], y: [HL+14]
  mov   a,[hl+13]
  xor   a,[hl+21]
  push  ax                  ; the sign
  movw  ax,[hl+20]
  addw  ax,ax
  shrw  ax,5
  decw  ax
  cmpw  ax,#0x7fe
  skc
  br    $!.L_slow
  movw  bc,ax
  movw  ax,[hl+12]
  addw  ax,ax
  shrw  ax,5
  decw  ax
  cmpw  ax,#0x7fe
  skc
  br    $!.L_slow
  subw  ax,bc
  addw  ax,#1023
  push  ax                  ; the exponent, if x is not below y
  mov   a,[hl+12]
  and   a,#0x0f
  or    a,#0x10
  mov   [hl+12],a
  mov   a,[hl+20]
  and   a,#0x0f
  or    a,#0x10
  mov   [hl+20],a
  clrb  a
  mov   [hl+13],a
  mov   [hl+21],a
.L_divide:
  clrw  ax
  push  ax
  push  ax
  push  ax
  push  ax
  push  ax
  push  ax
  push  ax
  push  ax
  movw  ax,sp
  addw  ax,#F_X
  movw  hl,ax               ; x: [HL], y: [HL+8]
  movw  ax,[hl+6]
  cmpw  ax,[hl+14]
  bnz   $1f
  movw  ax,[hl+4]
  cmpw  ax,[hl+12]
  bnz   $1f
  movw  ax,[hl+2]
  cmpw  ax,[hl+10]
  bnz   $1f
  movw  ax,[hl]
  cmpw  ax,[hl+8]
1:
#if DIGITS
  bc    $2f
  ; x is not below y: half of it is
  SHIFT_UP F_X, 8, 10
  br    $3f
2:
  movw  ax,[sp+F_EXP]
  decw  ax
  movw  [sp+F_EXP],ax
  SHIFT_UP F_X, 8, 11
3:
  SHIFT_UP F_Y, F_Y, 11
  movw  ax,sp
  addw  ax,#6
  movw  hl,ax
  call  $!.L_digit
  call  $!.L_digit
  call  $!.L_digit
  call  $!.L_digit
  ; the remainder is the four words above HL
  mov   a,[hl+2]
  or    a,[hl+3]
  or    a,[hl+4]
  or    a,[hl+5]
  or    a,[hl+6]
  or    a,[hl+7]
  or    a,[hl+8]
  or    a,[hl+9]
  mov   [sp+0],a
#else
  bnc   $2f
  movw  ax,[sp+F_EXP]
  decw  ax
  movw  [sp+F_EXP],ax
2:
  ; A bit of the quotient at a time until bit 63 is set: BC and the three
  ; words at [DE+2]
  movw  ax,sp
  addw  ax,#8
  movw  de,ax
  clrw  bc
.L_bit:
  movw  ax,[hl+6]
  cmpw  ax,[hl+14]
  bnz   $3f
  movw  ax,[hl+4]
  cmpw  ax,[hl+12]
  bnz   $3f
  movw  ax,[hl+2]
  cmpw  ax,[hl+10]
  bnz   $3f
  movw  ax,[hl]
  cmpw  ax,[hl+8]
3:
  bc    $4f
  movw  ax,[hl]
  subw  ax,[hl+8]
  movw  [hl],ax
  movw  ax,[hl+2]
  xch   a,x
  subc  a,[hl+10]
  xch   a,x
  subc  a,[hl+11]
  movw  [hl+2],ax
  movw  ax,[hl+4]
  xch   a,x
  subc  a,[hl+12]
  xch   a,x
  subc  a,[hl+13]
  movw  [hl+4],ax
  movw  ax,[hl+6]
  xch   a,x
  subc  a,[hl+14]
  xch   a,x
  subc  a,[hl+15]
  movw  [hl+6],ax
  incw  bc
4:
  mov   a,[de+7]
  bt    a.7,$5f
  movw  ax,[hl]
  addw  ax,ax
  movw  [hl],ax
  movw  ax,[hl+2]
  rolwc ax,1
  movw  [hl+2],ax
  movw  ax,[hl+4]
  rolwc ax,1
  movw  [hl+4],ax
  movw  ax,[hl+6]
  rolwc ax,1
  movw  [hl+6],ax
  shlw  bc,1
  movw  ax,[de+2]
  rolwc ax,1
  movw  [de+2],ax
  movw  ax,[de+4]
  rolwc ax,1
  movw  [de+4],ax
  movw  ax,[de+6]
  rolwc ax,1
  movw  [de+6],ax
  br    $.L_bit
5:
  movw  ax,bc
  movw  [de],ax
  ; the remainder is where x was
  mov   a,[hl]
  or    a,[hl+1]
  or    a,[hl+2]
  or    a,[hl+3]
  or    a,[hl+4]
  or    a,[hl+5]
  or    a,[hl+6]
  or    a,[hl+7]
  mov   [sp+0],a
#endif

  ; The quotient is at [SP+8], and at [SP+0] whether there is a remainder.
  ; Its top 53 bits to [HL+2..9], the 11 bits below them to the top of [HL],
  ; and the remainder to its lowest bit.
  movw  ax,sp
  addw  ax,#6
  movw  hl,ax
  movw  ax,[hl+2]
  shlw  ax,5
  movw  [hl],ax
  movw  ax,[hl+2]
  shrw  ax,11
  movw  bc,ax
  movw  ax,[hl+4]
  shlw  ax,5
  addw  ax,bc
  movw  [hl+2],ax
  movw  ax,[hl+4]
  shrw  ax,11
  movw  bc,ax
  movw  ax,[hl+6]
  shlw  ax,5
  addw  ax,bc
  movw  [hl+4],ax
  movw  ax,[hl+6]
  shrw  ax,11
  movw  bc,ax
  movw  ax,[hl+8]
  shlw  ax,5
  addw  ax,bc
  movw  [hl+6],ax
  movw  ax,[hl+8]
  shrw  ax,11
  movw  [hl+8],ax
  mov   a,[sp+0]
  cmp0  a
  skz
  set1  [hl].0
  ; [HL]: the 16 bits below the last place, [HL+2..9]: the mantissa
  movw  ax,[sp+F_EXP]
  movw  bc,ax
  ; the sign to bit 63, and to the result
  mov   a,[sp+F_SIGN]
  and   a,#0x80
  mov   [hl+9],a
  movw  ax,[sp+F_RES]
  movw  de,ax
#ifdef __OPTIMIZE_SIZE__
  call  !!__REL_d_pack
  addw  sp,#F_SIZE
  ret
#else
  D_PACK F_SIZE, 1
#endif

  ; an exponent is 0 or 0x7ff
.L_slow:
  pop   ax
  pop   de                  ; where the result goes
  push  ax                  ; the flags of __REL_d_check
  movw  hl,sp
  call  !!__REL_d_check
  bt    [hl].1,$.L_x_special
  bt    [hl].5,$.L_y_special
  mov1  cy,[hl].2
  and1  cy,[hl].3
  bc    $.L_x_zero
  mov1  cy,[hl].6
  and1  cy,[hl].7
  bc    $.L_inf             ; x / 0
  ; a subnormal operand
  movw  ax,hl
  addw  ax,#6
  movw  hl,ax
  call  $!.L_unpack
  push  bc
  movw  ax,hl
  addw  ax,#8
  movw  hl,ax
  call  $!.L_unpack
  pop   ax
  subw  ax,bc
  addw  ax,#1023
  movw  bc,ax
  pop   ax                  ; the flags
  push  de
  mov   a,x
  mov1  cy,a.0
  xor1  cy,a.4
  clrb  a
  rorc  a,1
  push  ax                  ; the sign
  push  bc                  ; the exponent
  br    $!.L_divide
.L_x_special:
  bf    [hl].3,$.L_nan      ; x is a NaN
  bt    [hl].5,$.L_nan      ; infinity / infinity, infinity / NaN
.L_inf:
  mov1  cy,[hl].0
  xor1  cy,[hl].4
  pop   ax
  br    !!__REL_d_inf
.L_y_special:
  bt    [hl].7,$.L_zero     ; x / infinity
.L_nan:
  pop   ax
  clrw  ax
  decw  ax
  movw  [de],ax
  movw  [de+2],ax
  movw  [de+4],ax
  movw  [de+6],ax
  ret
.L_x_zero:
  mov1  cy,[hl].6
  and1  cy,[hl].7
  bc    $.L_nan             ; 0 / 0
.L_zero:
  mov1  cy,[hl].0
  xor1  cy,[hl].4
  pop   ax
  clrw  ax
  movw  [de],ax
  movw  [de+2],ax
  movw  [de+4],ax
  mov1  a.7,cy
  movw  [de+6],ax
  ret

  ; The operand at HL: its exponent to BC, its mantissa with the hidden bit
  ; at bit 52. A subnormal one (it is not 0) is shifted up to there, and its
  ; exponent is 1 less the number of places.
.L_unpack:
  movw  ax,[hl+6]
  addw  ax,ax
  shrw  ax,5
  movw  bc,ax
  mov   a,[hl+6]
  and   a,#0x0f
  mov   [hl+6],a
  clrb  a
  mov   [hl+7],a
  movw  ax,bc
  or    a,x
  bnz   $2f
  incw  bc
1:
  mov   a,[hl+6]
  bt    a.4,$3f
  decw  bc
  movw  ax,[hl]
  addw  ax,ax
  movw  [hl],ax
  movw  ax,[hl+2]
  rolwc ax,1
  movw  [hl+2],ax
  movw  ax,[hl+4]
  rolwc ax,1
  movw  [hl+4],ax
  movw  ax,[hl+6]
  rolwc ax,1
  movw  [hl+6],ax
  br    $1b
2:
  mov   a,[hl+6]
  or    a,#0x10
  mov   [hl+6],a
3:
  ret

#if DIGITS
  ; The next digit of the quotient. The remainder is the five words at HL,
  ; the lowest of them 0; y is at SP + F_Y + 4. The digit goes where the top
  ; word of the remainder was, and HL down a word.
.L_digit:
  movw  ax,[sp+F_Y+4+6]
  movw  de,ax
  movw  ax,[hl+8]
  movw  bc,ax
  cmpw  ax,de
  movw  ax,#0xffff
  bz    $1f                 ; equal top digits: the division would give 65536
  movw  ax,[hl+6]
  DIV32
1:
  push  ax                  ; two more to y from here
  ; remainder -= digit * y; DE: what is taken from the next word
  movw  bc,ax
  movw  ax,[sp+F_Y+4+2]
  MUL16
  movw  de,ax
  clrw  ax
  subw  ax,de
  movw  [hl],ax
  movw  ax,bc
  sknc
  incw  ax
  movw  de,ax
  movw  ax,[sp+0]
  movw  bc,ax
  movw  ax,[sp+F_Y+4+4]
  MUL16
  addw  ax,de
  sknc
  incw  bc
  movw  de,ax
  movw  ax,[hl+2]
  subw  ax,de
  movw  [hl+2],ax
  movw  ax,bc
  sknc
  incw  ax
  movw  de,ax
  movw  ax,[sp+0]
  movw  bc,ax
  movw  ax,[sp+F_Y+4+6]
  MUL16
  addw  ax,de
  sknc
  incw  bc
  movw  de,ax
  movw  ax,[hl+4]
  subw  ax,de
  movw  [hl+4],ax
  movw  ax,bc
  sknc
  incw  ax
  movw  de,ax
  movw  ax,[sp+0]
  movw  bc,ax
  movw  ax,[sp+F_Y+4+8]
  MUL16
  addw  ax,de
  sknc
  incw  bc
  movw  de,ax
  movw  ax,[hl+6]
  subw  ax,de
  movw  [hl+6],ax
  movw  ax,bc
  sknc
  incw  ax
  movw  de,ax
  movw  ax,[hl+8]
  subw  ax,de               ; 0, or below it for a digit that was too high
  bnc   $2f
  movw  [hl+8],ax
  movw  ax,sp
  addw  ax,#F_Y+4+2
  movw  de,ax
  call  $!.L_add_back
2:
  pop   ax
  movw  [hl+8],ax
  decw  hl
  decw  hl
  ret

  ; The digit at [SP+4] was too high: one less and y (at DE) added to the
  ; remainder (at HL) until it is not negative any more.
.L_add_back:
  movw  ax,[sp+4]
  decw  ax
  movw  [sp+4],ax
  mov   a,[de]
  add   a,[hl]
  mov   [hl],a
  mov   a,[de+1]
  addc  a,[hl+1]
  mov   [hl+1],a
  mov   a,[de+2]
  addc  a,[hl+2]
  mov   [hl+2],a
  mov   a,[de+3]
  addc  a,[hl+3]
  mov   [hl+3],a
  mov   a,[de+4]
  addc  a,[hl+4]
  mov   [hl+4],a
  mov   a,[de+5]
  addc  a,[hl+5]
  mov   [hl+5],a
  mov   a,[de+6]
  addc  a,[hl+6]
  mov   [hl+6],a
  mov   a,[de+7]
  addc  a,[hl+7]
  mov   [hl+7],a
  movw  ax,[hl+8]
  sknc
  incw  ax
  movw  [hl+8],ax
  or    a,x
  bnz   $.L_add_back
  ret

#if !_RL78_S3
  ; BC:AX / DE to AX with the divider unit
.L_div32:
  push  psw
  di
  mov   !LOWW(MDUC),#0x80
  movw  MDAL,ax
  movw  ax,bc
  movw  MDAH,ax
  movw  ax,de
  movw  MDBL,ax
  clrw  ax
  movw  MDBH,ax
  mov   !LOWW(MDUC),#0x81
1:
  mov   a,!LOWW(MDUC)
  bt    a.0,$1b
  movw  ax,MDAL
  pop   psw
  ret
#endif
#endif
.Lfunc_end1:
  .size __COM_ddiv, .Lfunc_end1-__COM_ddiv

#ifdef __FAR_DATA__
#undef __COM_ddiv
  .globl __COM_ddiv
  .type  __COM_ddiv,@function
__COM_ddiv:
  subw  sp, #8        ; space for the tmp retval
  push  ax            ; save the addr of the org retval (far ptr)
  push  de
#ifdef __OPTIMIZE_SIZE__
  mov   e, #8         ; copy args using a loop
1:
  movw  ax,[sp+30]
  push  ax
  dec   e
  bnz   $1b
#else
  movw  ax,[sp+30]    ; copy arg 2
  push  ax
  movw  ax,[sp+30]
  push  ax
  movw  ax,[sp+30]
  push  ax
  movw  ax,[sp+30]
  push  ax
  movw  ax,[sp+30]    ; copy arg 1
  push  ax
  movw  ax,[sp+30]
  push  ax
  movw  ax,[sp+30]
  push  ax
  movw  ax,[sp+30]
  push  ax
#endif
  movw  ax, sp        ; set AX to the addr of the tmp retval
  addw  ax, #20
  call  !!__COM_ddiv_nd
  addw  sp, #16       ; get rid of the arg copies from the stack
  pop   hl            ; get the addr of org retval in ES:HL
  pop   ax
  mov   es, a
  pop   ax            ; copy the tmp retval to the org one
  movw  es:[hl], ax
  pop   ax
  movw  es:[hl+2], ax
  pop   ax
  movw  es:[hl+4], ax
  pop   ax
  movw  es:[hl+6], ax
  ret
.Lfunc_end2:
  .size __COM_ddiv, .Lfunc_end2-__COM_ddiv
#endif

  .weak ___divdf3
  .type ___divdf3,@function
  .set  ___divdf3, __COM_ddiv

