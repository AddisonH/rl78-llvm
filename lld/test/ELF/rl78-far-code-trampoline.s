# REQUIRES: rl78
## With far code (-mfar-code), a plain 16-bit reference to a function is a
## near pointer to it (a C++ vtable slot). A function above 64 KiB gets a
## trampoline in near code for it; the halves of a far pointer do not.

# RUN: llvm-mc -filetype=obj -triple=rl78 %s -o %t.o
# RUN: echo 'SECTIONS { .lowtext 0x100 : { *(.lowtext) } .data 0x200 : { *(.data) } .text 0x300 : { *(.text) } .textf 0x20000 : { *(.textf) } }' > %t.ld
# RUN: ld.lld -mfar-code -T %t.ld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn -j .lowtext %t | FileCheck %s --check-prefix=PLT
# RUN: llvm-objdump -s -j .data %t | FileCheck %s --check-prefix=DATA

# PLT:      100: br !!0x20000 <_far>
# PLT-NOT:  br

## slot -> the trampoline; near slot -> the function; far pointer -> 020000.
# DATA: 0200 00010003 00000200

	.section .textf,"ax",@progbits
	.globl _far
	.type _far,@function
_far:
	ret

	.text
	.globl _near
	.type _near,@function
_near:
	ret

	.data
	.short _far
	.short _near
	.short LOWW(_far)
	.byte LOW(HIGHW(_far))
	.byte 0
