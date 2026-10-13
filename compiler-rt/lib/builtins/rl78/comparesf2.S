//===-- comparesf2.S - Implement single-precision comparisons -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements __lesf2, __gesf2, __unordsf2 and their aliases for the
// compiler_rt library.
//
//===----------------------------------------------------------------------===//
//	int __lesf2(float x, float y);	also __ltsf2, __eqsf2, __nesf2
//	int __gesf2(float x, float y);	also __gtsf2
//	int __unordsf2(float x, float y);
//
//	input:
//		x = BC:AX
//		y = [SP+4]
//	output:
//		AX: -1 (x < y), 0 (x == y) or 1 (x > y). With a NaN, 1 from
//		__lesf2 and -1 from __gesf2, so that every comparison is false.
//		__unordsf2: 1 with a NaN, 0 otherwise.
//===----------------------------------------------------------------------===//

  .file   "comparesf2.S"

  .text

  .globl ___gesf2
  .type  ___gesf2,@function
  .globl ___gtsf2
  .type  ___gtsf2,@function
___gesf2:
___gtsf2:
  movw  hl,#0xffff
  br    $1f
.Lfunc_end1:
  .size ___gesf2, .Lfunc_end1-___gesf2
  .size ___gtsf2, .Lfunc_end1-___gtsf2

  .globl ___lesf2
  .type  ___lesf2,@function
  .globl ___ltsf2
  .type  ___ltsf2,@function
  .globl ___eqsf2
  .type  ___eqsf2,@function
  .globl ___nesf2
  .type  ___nesf2,@function
___lesf2:
___ltsf2:
___eqsf2:
___nesf2:
  movw  hl,#1
1:
  push  hl                  ; the answer with a NaN
  movw  hl,sp               ; y: [HL+6]
  movw  de,ax
  ; a NaN is above 0x7f800000 without its sign
  movw  ax,bc
  addw  ax,ax
  cmpw  ax,#0xff00
  bnc   $.L_x_top
.L_y:
  movw  ax,[hl+8]
  addw  ax,ax
  cmpw  ax,#0xff00
  bnc   $.L_y_top
.L_ordered:
  pop   ax
  mov   a,b
  xor   a,[hl+9]
  shl   a,1
  bc    $.L_signs
  ; the same sign: the larger bits are the larger number, or the smaller
  ; one when they are negative
  movw  ax,bc
  cmpw  ax,[hl+8]
  bz    $.L_low
.L_differ:
  mov   a,b
  xor1  cy,a.7
.L_less:                    ; CY: x < y
  onew  ax
  sknc
  movw  ax,#0xffff
  ret
.L_low:
  movw  ax,de
  cmpw  ax,[hl+6]
  bnz   $.L_differ
.L_equal:
  clrw  ax
  ret
.L_signs:
  ; +0 and -0 are equal; otherwise the negative one is the smaller one
  movw  ax,bc
  addw  ax,ax
  or    a,x
  or    a,d
  or    a,e
  bnz   $1f
  movw  ax,[hl+8]
  addw  ax,ax
  or    a,x
  or    a,[hl+7]
  or    a,[hl+6]
  bz    $.L_equal
1:
  mov   a,b
  mov1  cy,a.7
  br    $.L_less
.L_x_top:                   ; the exponent of x is 0xff
  bnz   $.L_unordered
  movw  ax,de
  or    a,x
  bz    $.L_y
.L_unordered:
  pop   ax
  ret
.L_y_top:
  bnz   $.L_unordered
  movw  ax,[hl+6]
  or    a,x
  bz    $.L_ordered
  br    $.L_unordered
.Lfunc_end2:
  .size ___lesf2, .Lfunc_end2-___lesf2
  .size ___ltsf2, .Lfunc_end2-___ltsf2
  .size ___eqsf2, .Lfunc_end2-___eqsf2
  .size ___nesf2, .Lfunc_end2-___nesf2

  .globl ___unordsf2
  .type  ___unordsf2,@function
___unordsf2:
  movw  hl,sp               ; y: [HL+4]
  movw  de,ax
  movw  ax,bc
  addw  ax,ax
  cmpw  ax,#0xff00
  bnc   $3f
1:
  movw  ax,[hl+6]
  addw  ax,ax
  cmpw  ax,#0xff00
  bnc   $4f
2:
  clrw  ax
  ret
3:
  bnz   $5f
  movw  ax,de
  or    a,x
  bz    $1b
5:
  onew  ax
  ret
4:
  bnz   $5b
  movw  ax,[hl+4]
  or    a,x
  bz    $2b
  br    $5b
.Lfunc_end3:
  .size ___unordsf2, .Lfunc_end3-___unordsf2
