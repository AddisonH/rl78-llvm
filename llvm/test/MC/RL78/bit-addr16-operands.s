# The address of a "!addr16.bit" operand is a number in any radix, an
# absolute alias or a symbol (with an addend in parentheses). It used to be
# read as hexadecimal only if it contained an "f" and as decimal otherwise:
# !0x1234.3 became a reference to a symbol named "0x1234", !buf.3 encoded
# address 000BH, and the addend of !(buf+1).3 was dropped.

# RUN: llvm-mc -triple=rl78 -filetype=obj %s -o - | llvm-objdump -dr - | FileCheck %s
# RUN: not llvm-mc -triple=rl78 --defsym=ERR=1 %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=ERR

.ifndef ERR
# CHECK:      71 30 34 12  set1 !0xf1234.3
	set1 !0x1234.3
# CHECK-NEXT: 71 08 34 12  clr1 !0xf1234.0
	clr1 !4660.0
# CHECK-NEXT: 71 10 0f 00  set1 !0xf000f.1
	set1 !017.1
# CHECK-NEXT: 71 30 00 00  set1 !0xf0000.3
# CHECK-NEXT: R_RL78_DIR16U_RAM fab{{$}}
	set1 !fab.3
# CHECK-NEXT: 71 20 00 00  set1 !0xf0000.2
# CHECK-NEXT: R_RL78_DIR16U_RAM buf{{$}}
	set1 !buf.2
# CHECK-NEXT: 71 30 00 00  set1 !0xf0000.3
# CHECK-NEXT: R_RL78_DIR16U_RAM buf+0x1{{$}}
	set1 !(buf+1).3
# CHECK-NEXT: 71 70 00 00  set1 !0xf0000.7
# CHECK-NEXT: R_RL78_DIR16U_RAM buf+0x101{{$}}
	set1 !(buf+0x101).7
# CHECK-NEXT: 11 71 58 34 12 clr1 es:!0x1234.5
	clr1 es:!0x1234.5
# CHECK-NEXT: 11 71 58 00 00 clr1 es:!0x0.5
# CHECK-NEXT: R_RL78_DIR20U_16 fab{{$}}
	clr1 es:!fab.5
	.equ ALIAS, 0xfe80
# CHECK-NEXT: 71 40 80 fe  set1 !0xffe80.4
	set1 !ALIAS.4
.else
# Renesas-style hexadecimal (a trailing "h") is not accepted anywhere by this
# assembler; it must not be taken for something else here either.
# ERR: :[[#@LINE+1]]:9: error: unexpected token in argument list
	set1 !0a03ah.3
# ERR: :[[#@LINE+1]]:12: error: unexpected token in argument list
	set1 !1234h.3
# ERR: :[[#@LINE+1]]:12: error: unexpected token in argument list
	clr1 es:!0a03ah.3
.endif
