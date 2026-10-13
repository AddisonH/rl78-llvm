//===-- comparedf2.S - Implement double-precision comparisons -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements __ledf2, __gedf2, __unorddf2 and their aliases for the
// compiler_rt library.
//
//===----------------------------------------------------------------------===//
//	int __ledf2(double x, double y);	also __ltdf2, __eqdf2, __nedf2
//	int __gedf2(double x, double y);	also __gtdf2
//	int __unorddf2(double x, double y);
//
//	input:
//		x = [SP+4]
//		y = [SP+12]
//	output:
//		AX: -1 (x < y), 0 (x == y) or 1 (x > y). With a NaN, 1 from
//		__ledf2 and -1 from __gedf2, so that every comparison is false.
//		__unorddf2: 1 with a NaN, 0 otherwise.
//===----------------------------------------------------------------------===//

  .file   "comparedf2.S"

  .text

  .globl ___gedf2
  .type  ___gedf2,@function
  .globl ___gtdf2
  .type  ___gtdf2,@function
___gedf2:
___gtdf2:
  movw  hl,#0xffff
  br    $1f
.Lfunc_end1:
  .size ___gedf2, .Lfunc_end1-___gedf2
  .size ___gtdf2, .Lfunc_end1-___gtdf2

  .globl ___ledf2
  .type  ___ledf2,@function
  .globl ___ltdf2
  .type  ___ltdf2,@function
  .globl ___eqdf2
  .type  ___eqdf2,@function
  .globl ___nedf2
  .type  ___nedf2,@function
___ledf2:
___ltdf2:
___eqdf2:
___nedf2:
  movw  hl,#1
1:
  push  hl                  ; the answer with a NaN
  movw  hl,sp               ; x: [HL+6], y: [HL+14]
  ; a NaN is above 0x7ff0000000000000 without its sign
  movw  ax,[hl+12]
  addw  ax,ax
  cmpw  ax,#0xffe0
  bnc   $.L_x_top
.L_y:
  movw  ax,[hl+20]
  addw  ax,ax
  cmpw  ax,#0xffe0
  bnc   $.L_y_top
.L_ordered:
  pop   ax
  mov   a,[hl+13]
  xor   a,[hl+21]
  shl   a,1
  bc    $.L_signs
  ; the same sign: the larger bits are the larger number, or the smaller
  ; one when they are negative
  movw  ax,[hl+12]
  cmpw  ax,[hl+20]
  bz    $.L_lower
.L_differ:
  mov   a,[hl+13]
  xor1  cy,a.7
.L_less:                    ; CY: x < y
  onew  ax
  sknc
  movw  ax,#0xffff
  ret
.L_lower:
  movw  ax,[hl+10]
  cmpw  ax,[hl+18]
  bnz   $.L_differ
  movw  ax,[hl+8]
  cmpw  ax,[hl+16]
  bnz   $.L_differ
  movw  ax,[hl+6]
  cmpw  ax,[hl+14]
  bnz   $.L_differ
.L_equal:
  clrw  ax
  ret
.L_signs:
  ; +0 and -0 are equal; otherwise the negative one is the smaller one
  movw  ax,[hl+12]
  addw  ax,ax
  or    a,x
  or    a,[hl+11]
  or    a,[hl+10]
  or    a,[hl+9]
  or    a,[hl+8]
  or    a,[hl+7]
  or    a,[hl+6]
  bnz   $1f
  movw  ax,[hl+20]
  addw  ax,ax
  or    a,x
  or    a,[hl+19]
  or    a,[hl+18]
  or    a,[hl+17]
  or    a,[hl+16]
  or    a,[hl+15]
  or    a,[hl+14]
  bz    $.L_equal
1:
  mov   a,[hl+13]
  mov1  cy,a.7
  br    $.L_less
.L_x_top:                   ; the exponent of x is 0x7ff
  bnz   $.L_unordered
  mov   a,[hl+11]
  or    a,[hl+10]
  or    a,[hl+9]
  or    a,[hl+8]
  or    a,[hl+7]
  or    a,[hl+6]
  bz    $.L_y
.L_unordered:
  pop   ax
  ret
.L_y_top:
  bnz   $.L_unordered
  mov   a,[hl+19]
  or    a,[hl+18]
  or    a,[hl+17]
  or    a,[hl+16]
  or    a,[hl+15]
  or    a,[hl+14]
  bz    $.L_ordered
  br    $.L_unordered
.Lfunc_end2:
  .size ___ledf2, .Lfunc_end2-___ledf2
  .size ___ltdf2, .Lfunc_end2-___ltdf2
  .size ___eqdf2, .Lfunc_end2-___eqdf2
  .size ___nedf2, .Lfunc_end2-___nedf2

  .globl ___unorddf2
  .type  ___unorddf2,@function
___unorddf2:
  movw  hl,sp               ; x: [HL+4], y: [HL+12]
  movw  ax,[hl+10]
  addw  ax,ax
  cmpw  ax,#0xffe0
  bnc   $3f
1:
  movw  ax,[hl+18]
  addw  ax,ax
  cmpw  ax,#0xffe0
  bnc   $4f
2:
  clrw  ax
  ret
3:
  bnz   $5f
  mov   a,[hl+9]
  or    a,[hl+8]
  or    a,[hl+7]
  or    a,[hl+6]
  or    a,[hl+5]
  or    a,[hl+4]
  bz    $1b
5:
  onew  ax
  ret
4:
  bnz   $5b
  mov   a,[hl+17]
  or    a,[hl+16]
  or    a,[hl+15]
  or    a,[hl+14]
  or    a,[hl+13]
  or    a,[hl+12]
  bz    $2b
  br    $5b
.Lfunc_end3:
  .size ___unorddf2, .Lfunc_end3-___unorddf2
