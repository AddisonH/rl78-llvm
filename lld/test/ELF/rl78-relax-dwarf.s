# REQUIRES: rl78
## DWARF line and frame information follows linker relaxation: the address
## advances and lengths that span a relaxable instruction are relocations
## (R_RL78_SYM, R_RL78_SYM, R_RL78_OPsub, R_RL78_ABS*), not assembly-time
## constants. "call !!_f" shrinks to "call !_f" (4 -> 3 bytes).

# RUN: llvm-mc -filetype=obj -triple=rl78 -mattr=+relax %s -o %t.o
# RUN: echo 'SECTIONS { .text 0x100 : { *(.text) } }' > %t.ld
# RUN: ld.lld --relax -T %t.ld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s --check-prefix=CODE
# RUN: llvm-dwarfdump --debug-line --debug-frame %t | FileCheck %s --check-prefix=RELAX
# RUN: ld.lld --no-relax -T %t.ld %t.o -o %t.norelax
# RUN: llvm-dwarfdump --debug-line --debug-frame %t.norelax | FileCheck %s --check-prefix=NORELAX

# CODE:      100: push ax
# CODE-NEXT: 101: call !0x106 <_f>
# CODE-NEXT: 104: pop ax
# CODE-NEXT: 105: ret
# CODE:      106: ret

# RELAX:      FDE cie=00000000 pc=00000100...00000106
# RELAX:      0x100: CFA=SPreg+4
# RELAX-NEXT: 0x101: CFA=SPreg+6
# RELAX-NEXT: 0x105: CFA=SPreg+4
# RELAX:      0x0000000000000100 1
# RELAX-NEXT: 0x0000000000000101 2
# RELAX-NEXT: 0x0000000000000104 3
# RELAX-NEXT: 0x0000000000000106 5
# RELAX-NEXT: 0x0000000000000107 5 {{.*}} end_sequence

# NORELAX:      FDE cie=00000000 pc=00000100...00000107
# NORELAX:      0x0000000000000105 3
# NORELAX-NEXT: 0x0000000000000107 5

	.text
	.file 1 "t.c"
	.cfi_sections .debug_frame
	.globl	_start
_start:
	.cfi_startproc
	.loc	1 1 0
	push	ax
	.cfi_adjust_cfa_offset 2
	.loc	1 2 0
	call	!!_f
	.loc	1 3 0
	pop	ax
	.cfi_adjust_cfa_offset -2
	ret
	.cfi_endproc
	.globl	_f
_f:
	.loc	1 5 0
	ret
