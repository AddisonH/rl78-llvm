//===-- COM_dmul.s - Implement _COM_dmul ----------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements _COM_dmul for the compiler_rt library.
//
//===----------------------------------------------------------------------===//
//	_COM_dmul
//
//	double _COM_dmul(double x, double y);
//
//	input:
//		x = [SP+4]
//		y = [SP+12]
//	output:
//		[AX] ([A:DE] for far data)
//===----------------------------------------------------------------------===//
  #include "def.S"

#ifdef __FAR_DATA__
#define __COM_dmul  __COM_dmul_nd
#endif

  .globl __COM_dmul
  .extern __COM_mului
  .extern __REL_d_check
  .extern __REL_d_inf

//	The two 53-bit mantissas are multiplied where they are, a 16-bit digit
//	of y at a time, into 106 bits. Its top 53 bits are the result; the 16
//	bits below them, with everything further down collected in their lowest
//	bit, round it to nearest even.
//
//	The frame, from SP, once the product is there:
//	   0  the product, eight words
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
#define MUL16 mulhu
#else
#define MUL16 call $!.L_mul16
#endif

  .text

  ; p[j .. j+4] += x * (digit j of y), p at HL; DE: what goes into the next
  ; word. The first row finds nothing there yet.
.macro ROW j, first
  movw  ax,[sp+F_Y+2*\j]
  movw  bc,ax
  movw  ax,[sp+F_X]
  MUL16
.if !\first
  addw  ax,[hl+2*\j]
  sknc
  incw  bc
.endif
  movw  [hl+2*\j],ax
  movw  ax,bc
  movw  de,ax
  movw  ax,[sp+F_Y+2*\j]
  movw  bc,ax
  movw  ax,[sp+F_X+2]
  MUL16
  addw  ax,de
  sknc
  incw  bc
.if !\first
  addw  ax,[hl+2*\j+2]
  sknc
  incw  bc
.endif
  movw  [hl+2*\j+2],ax
  movw  ax,bc
  movw  de,ax
  movw  ax,[sp+F_Y+2*\j]
  movw  bc,ax
  movw  ax,[sp+F_X+4]
  MUL16
  addw  ax,de
  sknc
  incw  bc
.if !\first
  addw  ax,[hl+2*\j+4]
  sknc
  incw  bc
.endif
  movw  [hl+2*\j+4],ax
  movw  ax,bc
  movw  de,ax
  movw  ax,[sp+F_Y+2*\j]
  movw  bc,ax
  movw  ax,[sp+F_X+6]
  MUL16
  addw  ax,de
  sknc
  incw  bc
.if !\first
  addw  ax,[hl+2*\j+6]
  sknc
  incw  bc
.endif
  movw  [hl+2*\j+6],ax
  movw  ax,bc
  movw  [hl+2*\j+8],ax
.endm

  .type  __COM_dmul,@function
__COM_dmul:
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
  addw  ax,bc
  subw  ax,#1021
  push  ax                  ; the exponent
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
.L_multiply:
#ifdef __OPTIMIZE_SIZE__
  subw  sp,#8
  clrw  ax
  push  ax
  push  ax
  push  ax
  push  ax
  movw  hl,sp
  movw  ax,[sp+F_Y]
  call  $!.L_row
  movw  ax,[sp+F_Y+2]
  call  $!.L_row
  movw  ax,[sp+F_Y+4]
  call  $!.L_row
  movw  ax,[sp+F_Y+6]
  call  $!.L_row
#else
  subw  sp,#16
  movw  hl,sp
  ROW   0,1
  ROW   1,0
  ROW   2,0
  ROW   3,0
#endif

  ; The product is below 2 ^ 106 and not below 2 ^ 104. With bit 105 clear,
  ; one place to the left (what is below the third word only counts as a
  ; whole); with it set the exponent is one more.
  movw  hl,sp
  mov   a,[hl+13]
  bt    a.1,$1f
  movw  ax,[hl+4]
  addw  ax,ax
  movw  [hl+4],ax
  movw  ax,[hl+6]
  rolwc ax,1
  movw  [hl+6],ax
  movw  ax,[hl+8]
  rolwc ax,1
  movw  [hl+8],ax
  movw  ax,[hl+10]
  rolwc ax,1
  movw  [hl+10],ax
  movw  ax,[hl+12]
  rolwc ax,1
  movw  [hl+12],ax
  br    $2f
1:
  movw  ax,[hl+F_EXP]
  incw  ax
  movw  [hl+F_EXP],ax
2:
  ; Bits 53..105 to [HL+6..13], the 16 bits below them to [HL+4], and whether
  ; anything is below those to [HL].
  mov   a,[hl+4]
  and   a,#0x1f
  or    a,[hl+3]
  or    a,[hl+2]
  or    a,[hl+1]
  or    a,[hl]
  mov   [hl],a
  movw  ax,[hl+4]
  shrw  ax,5
  movw  bc,ax
  movw  ax,[hl+6]
  shlw  ax,11
  addw  ax,bc
  movw  [hl+4],ax
  movw  ax,[hl+6]
  shrw  ax,5
  movw  bc,ax
  movw  ax,[hl+8]
  shlw  ax,11
  addw  ax,bc
  movw  [hl+6],ax
  movw  ax,[hl+8]
  shrw  ax,5
  movw  bc,ax
  movw  ax,[hl+10]
  shlw  ax,11
  addw  ax,bc
  movw  [hl+8],ax
  movw  ax,[hl+10]
  shrw  ax,5
  movw  bc,ax
  movw  ax,[hl+12]
  shlw  ax,11
  addw  ax,bc
  movw  [hl+10],ax
  movw  ax,[hl+12]
  shrw  ax,5
  movw  [hl+12],ax
  mov   a,[hl]
  incw  hl
  incw  hl
  incw  hl
  incw  hl
  cmp0  a
  skz
  set1  [hl].0
  ; [HL]: the 16 bits below the last place, [HL+2..9]: the mantissa
  movw  ax,[sp+F_EXP]
  movw  bc,ax
  decw  ax
  cmpw  ax,#0x7fe
  bnc   $.L_range
.L_round:
  ; BC: the exponent. With the hidden bit added to exponent - 1, a number
  ; without one has the exponent field 0, and a carry out of the mantissa
  ; when it is rounded up goes into the exponent.
  decw  bc
  movw  ax,bc
  shlw  ax,4
  addw  ax,[hl+8]
  movw  [hl+8],ax
  clrw  bc
  movw  ax,[hl]
  cmpw  ax,#0x8000
  bc    $2f                 ; below half of the last place
  bnz   $1f                 ; above
  mov   a,[hl+2]
  bf    a.0,$2f             ; half: to even
1:
  incw  bc
2:
  movw  ax,[sp+F_RES]
  movw  de,ax
  movw  ax,[hl+2]
  addw  ax,bc
  movw  [de],ax
  movw  ax,[hl+4]
  sknc
  addw  ax,#1
  movw  [de+2],ax
  movw  ax,[hl+6]
  sknc
  addw  ax,#1
  movw  [de+4],ax
  movw  ax,[hl+8]
  sknc
  addw  ax,#1
  movw  bc,ax
  mov   a,[sp+F_SIGN]
  shl   a,1
  movw  ax,bc
  mov1  a.7,cy
  movw  [de+6],ax
  addw  sp,#F_SIZE
  ret

  ; the exponent is below 1 or above 0x7fe
.L_range:
  mov   a,b
  bt    a.7,$.L_tiny
  movw  ax,bc
  or    a,x
  bz    $.L_tiny
  movw  ax,[sp+F_RES]
  movw  de,ax
  mov   a,[sp+F_SIGN]
  mov1  cy,a.7
  addw  sp,#F_SIZE
  br    !!__REL_d_inf
.L_tiny:
  ; a subnormal result: to the right until the exponent is 1; what falls
  ; out stays in the lowest bit
  onew  ax
  subw  ax,bc
  cmpw  ax,#64
  bc    $1f
  movw  ax,[sp+F_RES]
  movw  de,ax
  mov   a,[sp+F_SIGN]
  mov1  cy,a.7
  addw  sp,#F_SIZE
  br    $!.L_zero_cy
1:
  movw  bc,ax
2:
  movw  ax,[hl+8]
  shrw  ax,1
  movw  [hl+8],ax
  movw  ax,[hl+6]
  rorc  a,1
  xch   a,x
  rorc  a,1
  xch   a,x
  movw  [hl+6],ax
  movw  ax,[hl+4]
  rorc  a,1
  xch   a,x
  rorc  a,1
  xch   a,x
  movw  [hl+4],ax
  movw  ax,[hl+2]
  rorc  a,1
  xch   a,x
  rorc  a,1
  xch   a,x
  movw  [hl+2],ax
  movw  ax,[hl]
  rorc  a,1
  xch   a,x
  rorc  a,1
  xch   a,x
  movw  [hl],ax
  sknc
  set1  [hl].0
  dec   c
  bnz   $2b
  onew  bc
  br    $!.L_round

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
  bc    $.L_zero
  mov1  cy,[hl].6
  and1  cy,[hl].7
  bc    $.L_zero
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
  addw  ax,bc
  subw  ax,#1023
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
  br    $!.L_multiply
.L_x_special:
  bf    [hl].3,$.L_nan      ; x is a NaN
  bt    [hl].5,$1f
  mov1  cy,[hl].6
  and1  cy,[hl].7
  bc    $.L_nan             ; infinity * 0
  br    $.L_inf
1:
  bf    [hl].7,$.L_nan      ; y is a NaN
  br    $.L_inf
.L_y_special:
  bf    [hl].7,$.L_nan
  mov1  cy,[hl].2
  and1  cy,[hl].3
  bc    $.L_nan             ; 0 * infinity
.L_inf:
  mov1  cy,[hl].0
  xor1  cy,[hl].4
  pop   ax
  br    !!__REL_d_inf
.L_nan:
  pop   ax
  clrw  ax
  decw  ax
  movw  [de],ax
  movw  [de+2],ax
  movw  [de+4],ax
  movw  [de+6],ax
  ret
.L_zero:
  mov1  cy,[hl].0
  xor1  cy,[hl].4
  pop   ax
.L_zero_cy:
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

#ifdef __OPTIMIZE_SIZE__
  ; [HL .. HL+8] += x * AX, and HL to the next word.
  ; DE: what goes into the next word. From SP here x is 6 further away.
.L_row:
  push  ax
  movw  bc,ax
  movw  ax,[sp+F_X+6]
  MUL16
  addw  ax,[hl+0]
  sknc
  incw  bc
  movw  [hl],ax
  movw  ax,bc
  movw  de,ax
  movw  ax,[sp+0]
  movw  bc,ax
  movw  ax,[sp+F_X+8]
  MUL16
  addw  ax,de
  sknc
  incw  bc
  addw  ax,[hl+2]
  sknc
  incw  bc
  movw  [hl+2],ax
  movw  ax,bc
  movw  de,ax
  movw  ax,[sp+0]
  movw  bc,ax
  movw  ax,[sp+F_X+10]
  MUL16
  addw  ax,de
  sknc
  incw  bc
  addw  ax,[hl+4]
  sknc
  incw  bc
  movw  [hl+4],ax
  movw  ax,bc
  movw  de,ax
  movw  ax,[sp+0]
  movw  bc,ax
  movw  ax,[sp+F_X+12]
  MUL16
  addw  ax,de
  sknc
  incw  bc
  addw  ax,[hl+6]
  sknc
  incw  bc
  movw  [hl+6],ax
  movw  ax,bc
  movw  [hl+8],ax
  pop   ax
  incw  hl
  incw  hl
  ret
#endif

#if !_RL78_S3
.L_mul16:
  push  hl
  push  de
  call  !!__COM_mului
  pop   de
  pop   hl
  ret
#endif
.Lfunc_end1:
  .size __COM_dmul, .Lfunc_end1-__COM_dmul

#ifdef __FAR_DATA__
#undef __COM_dmul
  .globl __COM_dmul
  .type  __COM_dmul,@function
__COM_dmul:
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
  call  !!__COM_dmul_nd
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
  .size __COM_dmul, .Lfunc_end2-__COM_dmul
#endif

  .weak ___muldf3
  .type ___muldf3,@function
  .set  ___muldf3, __COM_dmul
  
