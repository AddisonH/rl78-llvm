# REQUIRES: rl78
## Two branches that each fit in "br $addr20" only when the other one does:
## the first reaches X only past a short second branch, and the second reaches
## Y exactly. Every pass chooses both from the same layout, so the two shrink
## together instead of taking turns, and address assignment converges.

# RUN: llvm-mc -filetype=obj -triple=rl78 -mattr=+relax %s -o %t.o
# RUN: echo 'SECTIONS { .text 0x100 : { *(.text) } }' > %t.ld
# RUN: ld.lld --relax -T %t.ld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

# CHECK:      100: br $0x181 <X>
# CHECK-NEXT: 102: br $0x183 <Y>
# CHECK:      183: ret

	.text
	.globl	_start
_start:
	br	!!X
	br	!!Y
	.rept	125
	nop
	.endr
X:
	nop
	nop
Y:
	ret
