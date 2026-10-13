# REQUIRES: rl78
## "br !!addr20" becomes "br $addr20" when the target is within reach of an
## 8-bit displacement once the branch itself is two bytes shorter: +127 is,
## +128 is not, whichever pass of the relaxation looks at it.

# RUN: llvm-mc -filetype=obj -triple=rl78 -mattr=+relax %s -o %t.o
# RUN: echo 'SECTIONS { .text 0x100 : { *(.text) } }' > %t.ld
# RUN: ld.lld --relax -T %t.ld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

# CHECK:      100: br $0x181 <_near>
# CHECK:      181: ret
# CHECK-NEXT: 182: br !0x205 <_far>
# CHECK:      205: ret

	.text
	.globl	_start
_start:
	br	!!_near
	.rept	127
	nop
	.endr
_near:
	ret
	br	!!_far
	.rept	128
	nop
	.endr
_far:
	ret
