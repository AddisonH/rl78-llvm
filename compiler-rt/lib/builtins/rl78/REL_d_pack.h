//===-- REL_d_pack.h - Round and pack a double ----------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The end of the double-precision routines: D_PACK in line, or a call of
// __REL_d_pack (which is D_PACK) when the library is built for size.
//
//	input:
//		[HL+2..9] = the mantissa, 53 bits with the hidden bit, or
//		            fewer for the exponent 1; the sign in bit 63
//		[HL]      = the 16 bits below its last place, everything
//		            further down collected in the lowest of them
//		BC        = the exponent; outside 1..2046 the result is an
//		            infinity, a subnormal number or 0
//		DE        = where the result goes
//
//	The mantissa is rounded to nearest even. With the hidden bit added to
//	exponent - 1, a number without one has the exponent field 0, and a
//	carry out of the mantissa when it is rounded up goes into the exponent.
//
//	D_PACK frame, tiny: \frame bytes are taken off the stack before the
//	return; \tiny is 0 where the exponent cannot be below 1.
//===----------------------------------------------------------------------===//

.macro D_PACK_RET frame
.if \frame
  addw  sp,#\frame
.endif
.endm

.macro D_PACK frame, tiny
  movw  ax,bc
.if \tiny
  decw  ax
  cmpw  ax,#0x7fe
  bnc   $3f
.else
  cmpw  ax,#0x7ff
  bz    $4f
.endif
0:
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
  movw  [de+6],ax
  D_PACK_RET \frame
  ret
.if \tiny
3:
  mov   a,b
  bt    a.7,$5f
  movw  ax,bc
  or    a,x
  bz    $5f
.endif
4:
  mov   a,[hl+9]
  mov1  cy,a.7
  D_PACK_RET \frame
  br    !!__REL_d_inf
.if \tiny
5:
  ; a subnormal result: to the right until the exponent is 1; what falls
  ; out stays in the lowest bit
  onew  ax
  subw  ax,bc
  cmpw  ax,#64
  bc    $6f
  mov   a,[hl+9]
  mov1  cy,a.7
  clrw  ax
  movw  [de],ax
  movw  [de+2],ax
  movw  [de+4],ax
  mov1  a.7,cy
  movw  [de+6],ax
  D_PACK_RET \frame
  ret
6:
  movw  bc,ax
  mov   a,[hl+9]
  push  ax                  ; the sign
  clrb  a
  mov   [hl+9],a
7:
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
  bnz   $7b
  pop   ax
  mov   [hl+9],a
  onew  bc
  br    $!0b
.endif
.endm
