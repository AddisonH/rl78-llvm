//===-- COM_dadd.s - Implement _COM_dadd ----------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements _COM_dadd for the compiler_rt library.
//
//===----------------------------------------------------------------------===//
//	_COM_dadd
//
//	double _COM_dadd(double x, double y);
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
#define __COM_dadd  __COM_dadd_nd
#endif

  .globl __COM_dadd
  .extern __REL_d_check
  .extern __REL_d_inf
  .extern __REL_d_pack

//	The operand with the larger exponent stays where it is; the other one is
//	shifted right by the difference of the exponents into a work area, with
//	16 bits kept below the last place and everything below those collected
//	in their lowest bit. The sum or difference is normalized, and rounded
//	and packed by D_PACK.
//
//	The shift is a multiplication: by a power of two below 65536 with MULHU
//	(a word at a time), below 256 with MULU (a byte at a time) on the cores
//	without MULHU, and a move by whole words or bytes.
//
//	An exponent of 0 counts as 1 without the hidden bit, so zeros and
//	subnormal numbers take the same way as everything else.
//
//	The frame, from SP, once the work area is there:
//	   0  the multiplier
//	   2  the work area (18 bytes)
//	  20  where in the work area the shifted operand begins
//	  22  the top byte of the larger operand (bit 7: the sign of the result)
//	  23  bit 7: the signs differ (subtract)
//	  24  the exponent of the larger operand
//	  26  where the result goes
#define F_WHERE 20
#define F_SIGN  22
#define F_SUB   23
#define F_EXP   24
#define F_RES   26
#define F_SIZE  28

  .text

  .type  __COM_dadd,@function
__COM_dadd:
  push  ax
  movw  ax,sp
  addw  ax,#6
  movw  de,ax               ; x
  addw  ax,#8
  movw  hl,ax               ; y
  movw  ax,[hl+6]
  addw  ax,ax
  shrw  ax,5
  movw  bc,ax
  movw  ax,[de+6]
  addw  ax,ax
  shrw  ax,5
  cmpw  ax,bc
  bh    $.L_ordered
  sknz
  br    $!.L_same_exponent
  xchw  ax,bc
.L_swap:
  xchw  ax,de
  xchw  ax,hl
  xchw  ax,de
.L_ordered:
  ; AX: the larger exponent, BC: the smaller one, DE: the operand with the
  ; larger one, HL: the other operand
  cmpw  ax,#0x7ff
  sknz
  br    $!.L_special
  push  ax
  subw  ax,bc
  cmpw  ax,#65
  skc
  br    $!.L_big
  xchw  ax,bc               ; BC: the difference
  or    a,x
  sknz
  br    $!.L_subnormal
  mov   a,[hl+6]
  and   a,#0x0f
  or    a,#0x10
  mov   [hl+6],a
.L_hidden_big:
  mov   a,[de+6]
  and   a,#0x0f
  or    a,#0x10
  mov   [de+6],a
.L_unpacked:
  mov   a,[de+7]
  mov   x,a
  xor   a,[hl+7]
  push  ax                  ; F_SIGN, F_SUB
  clrb  a
  mov   [de+7],a
  mov   [hl+7],a

#if _RL78_S3
  ; d = 16 * q + k with k in 1..16: the mantissa times 2 ^ (16 - k), five
  ; words T[0..4], and the shifted operand is the five words from T[q] on,
  ; a zero word below T[0] and three above T[4].
  ;    2  zero
  ;    4  T[0..4]
  ;   14  three zero words
  mov   a,c
  add   a,#15
  shr   a,4
  mov   x,a
  clrb  a
  push  ax                  ; F_WHERE: q + 1
  clrw  ax
  push  ax
  push  ax
  push  ax
  subw  sp,#10
  push  ax
  sub   a,c
  onew  bc
  mov1  cy,a.0
  sknc
  shlw  bc,1
  mov1  cy,a.1
  sknc
  shlw  bc,2
  mov1  cy,a.2
  sknc
  shlw  bc,4
  mov1  cy,a.3
  sknc
  shlw  bc,8
  push  bc                  ; the multiplier
  push  de
  movw  ax,[hl]
  mulhu
  movw  [sp+6],ax
  movw  ax,bc
  movw  de,ax               ; what goes into the next word
  movw  ax,[sp+2]
  movw  bc,ax
  movw  ax,[hl+2]
  mulhu
  addw  ax,de
  movw  [sp+8],ax
  movw  ax,bc
  movw  de,ax
  movw  ax,[sp+2]
  movw  bc,ax
  movw  ax,[hl+4]
  mulhu
  addw  ax,de
  movw  [sp+10],ax
  movw  ax,bc
  movw  de,ax
  movw  ax,[sp+2]
  movw  bc,ax
  movw  ax,[hl+6]
  mulhu
  addw  ax,de
  movw  [sp+12],ax
  movw  ax,bc
  movw  [sp+14],ax
  pop   de
  ; HL = T + 2 * q; the words below it only say whether anything is there
  movw  hl,sp
  incw  hl
  incw  hl
  mov   a,[sp+F_WHERE]
  cmp0  a
  bz    $2f
  incw  hl
  incw  hl
  dec   a
  bz    $2f
  mov   c,a
  clrb  a
1:
  or    a,[hl]
  or    a,[hl+1]
  incw  hl
  incw  hl
  dec   c
  bnz   $1b
  cmp0  a
  skz
  set1  [hl].0
2:
#else
  ; d = 8 * q + k with k in 1..8: the mantissa times 2 ^ (8 - k), eight
  ; bytes, goes q - 1 bytes below the ten bytes of the shifted operand.
  ;    4  six bytes for what falls below them
  ;   10  the shifted operand
  mov   a,c
  add   a,#7
  shr   a,3
  mov   x,a
  mov   a,#14
  sub   a,x
  mov   x,a
  clrb  a
  push  ax                  ; F_WHERE: from SP, with DE pushed as well
  clrw  ax
  push  ax
  push  ax
  push  ax
  push  ax
  push  ax
  push  ax
  push  ax
  push  ax
  push  ax
  sub   a,c
  mov   b,#1
  mov1  cy,a.0
  sknc
  shl   b,1
  mov1  cy,a.1
  sknc
  shl   b,2
  mov1  cy,a.2
  sknc
  shl   b,4
  push  bc                  ; the multiplier, in the high byte
  push  de
  movw  ax,sp
  movw  bc,ax
  movw  ax,[sp+F_WHERE+2]
  addw  ax,bc
  movw  de,ax
  movw  bc,#7               ; seven bytes, nothing from below
1:
  mov   a,[hl]
  incw  hl
  mov   x,a
  mov   a,[sp+3]
  mulu  x
  xch   a,x
  add   a,b
  mov   [de],a
  incw  de
  mov   a,x
  mov   b,a                 ; what goes into the next byte
  dec   c
  bnz   $1b
  mov   a,b
  mov   [de],a
  pop   de
  movw  ax,sp
  addw  ax,#4
  movw  hl,ax
  mov   a,[hl]
  or    a,[hl+1]
  or    a,[hl+2]
  or    a,[hl+3]
  or    a,[hl+4]
  or    a,[hl+5]
  incw  hl
  incw  hl
  incw  hl
  incw  hl
  incw  hl
  incw  hl
  skz
  set1  [hl].0
#endif

  ; [HL]: the 16 bits below the last place, [HL+2..9]: the shifted mantissa;
  ; [DE]: the mantissa of the larger operand. The result replaces the
  ; shifted operand.
  mov   a,[sp+F_SUB]
  bf    a.7,$.L_add
  br    $!.L_sub
.L_add:
  movw  ax,[de]
  addw  ax,[hl+2]
  movw  [hl+2],ax
  movw  ax,[de+2]
  xch   a,x
  addc  a,[hl+4]
  xch   a,x
  addc  a,[hl+5]
  movw  [hl+4],ax
  movw  ax,[de+4]
  xch   a,x
  addc  a,[hl+6]
  xch   a,x
  addc  a,[hl+7]
  movw  [hl+6],ax
  movw  ax,[de+6]
  xch   a,x
  addc  a,[hl+8]
  xch   a,x
  addc  a,[hl+9]
  movw  [hl+8],ax
  cmpw  ax,#0x20
  bnc   $.L_carry
.L_exponent:
  movw  ax,[sp+F_EXP]
  movw  bc,ax
.L_round:                   ; BC: the exponent
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
  D_PACK F_SIZE, 0
#endif

.L_carry:
  ; 54 bits: one to the right, the exponent one up
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
  movw  ax,[sp+F_EXP]
  incw  ax
  movw  bc,ax
  br    $!.L_round

.L_sub:
  clrw  ax
  subw  ax,[hl+0]
  movw  [hl],ax
  movw  ax,[de]
  xch   a,x
  subc  a,[hl+2]
  xch   a,x
  subc  a,[hl+3]
  movw  [hl+2],ax
  movw  ax,[de+2]
  xch   a,x
  subc  a,[hl+4]
  xch   a,x
  subc  a,[hl+5]
  movw  [hl+4],ax
  movw  ax,[de+4]
  xch   a,x
  subc  a,[hl+6]
  xch   a,x
  subc  a,[hl+7]
  movw  [hl+6],ax
  movw  ax,[de+6]
  xch   a,x
  subc  a,[hl+8]
  xch   a,x
  subc  a,[hl+9]
  movw  [hl+8],ax
  cmpw  ax,#0x10
  skc
  br    $!.L_exponent
  ; the leading bits cancelled: nothing left is +0, otherwise to the left
  ; until the hidden bit is there again or the exponent is 1
  mov   a,x
  or    a,[hl+7]
  or    a,[hl+6]
  or    a,[hl+5]
  or    a,[hl+4]
  or    a,[hl+3]
  or    a,[hl+2]
  or    a,[hl+1]
  or    a,[hl]
  movw  ax,[sp+F_EXP]
  movw  bc,ax
  bnz   $.L_normalize
  mov   [sp+F_SIGN],a       ; A is 0 here: exponents are below 0x7ff
  onew  bc
  br    $!.L_round
.L_normalize:
  movw  ax,bc
  cmpw  ax,#1
  bz    $1f
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
  movw  ax,[hl+8]
  rolwc ax,1
  movw  [hl+8],ax
  cmpw  ax,#0x10
  bc    $.L_normalize
1:
  br    $!.L_round


.L_nan:
  pop   ax
  clrw  ax
  decw  ax
  movw  [de],ax
  movw  [de+2],ax
  movw  [de+4],ax
  movw  [de+6],ax
  ret

  ; an exponent is 0x7ff
.L_special:
  pop   de                  ; where the result goes
  push  ax                  ; the flags of __REL_d_check
  movw  hl,sp
  call  !!__REL_d_check
  bf    [hl].1,$.L_y_special
  bf    [hl].3,$.L_nan      ; x is a NaN
  bf    [hl].5,$.L_x        ; y is finite
  bf    [hl].7,$.L_nan      ; y is a NaN
  mov1  cy,[hl].0
  xor1  cy,[hl].4
  bc    $.L_nan             ; infinity - infinity
.L_x:
  movw  ax,hl
  addw  ax,#6
  br    $.L_copy
.L_y_special:
  bf    [hl].7,$.L_nan
  movw  ax,hl
  addw  ax,#14
.L_copy:
  movw  hl,ax
  pop   ax
  br    $.L_return

  ; the smaller operand is less than a quarter of the last place of the
  ; larger one
.L_big:
  pop   ax                  ; the exponent
  movw  ax,de
  movw  hl,ax
  pop   de
.L_return:                  ; [DE] = [HL]
  movw  ax,[hl]
  movw  [de],ax
  movw  ax,[hl+2]
  movw  [de+2],ax
  movw  ax,[hl+4]
  movw  [de+4],ax
  movw  ax,[hl+6]
  movw  [de+6],ax
  ret

  ; the exponents are equal: the larger mantissa decides
.L_same_exponent:
  mov   a,[de+6]
  cmp   a,[hl+6]
  bnz   $1f
  movw  ax,[de+4]
  cmpw  ax,[hl+4]
  bnz   $1f
  movw  ax,[de+2]
  cmpw  ax,[hl+2]
  bnz   $1f
  movw  ax,[de]
  cmpw  ax,[hl+0]
1:
  movw  ax,bc
  skc
  br    $!.L_ordered
  br    $!.L_swap

  ; the exponent of the smaller operand is 0
.L_subnormal:
  movw  ax,bc
  or    a,x
  decw  bc                  ; its exponent counts as 1
  skz
  br    $!.L_hidden_big
  incw  bc                  ; so does the other one's
  pop   ax
  incw  ax
  push  ax
  br    $!.L_unpacked
.Lfunc_end1:
  .size __COM_dadd, .Lfunc_end1-__COM_dadd

#ifdef __FAR_DATA__
#undef __COM_dadd
  .globl __COM_dadd
  .type  __COM_dadd,@function
__COM_dadd:
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
  call  !!__COM_dadd_nd
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
  .size __COM_dadd, .Lfunc_end2-__COM_dadd
#endif

  .weak ___adddf3
  .type ___adddf3,@function
  .set  ___adddf3, __COM_dadd
