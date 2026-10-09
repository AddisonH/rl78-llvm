# With linker relaxation, label differences across a relaxable instruction
# are emitted as CC-RL operator relocations (push A, push B, subtract, store)
# instead of being folded: DWARF line advances become DW_LNS_fixed_advance_pc
# and CFA advances DW_CFA_advance_loc1. llvm-dwarfdump evaluates the
# relocation stack when reading the object. Without relaxation the
# differences are constants.

# RUN: llvm-mc -triple=rl78 -mattr=+relax -filetype=obj %s -o %t.o
# RUN: llvm-readobj -r %t.o | FileCheck %s --check-prefix=RELOC
# RUN: llvm-dwarfdump --debug-line --debug-frame %t.o 2>&1 | FileCheck %s --check-prefix=DUMP
# RUN: llvm-mc -triple=rl78 -filetype=obj %s -o %t.norelax.o
# RUN: llvm-readobj -r %t.norelax.o | FileCheck %s --check-prefix=NORELAX

# RELOC:      .rela.debug_frame {
# RELOC:        0x20 R_RL78_SYM
# RELOC-NEXT:   0x20 R_RL78_SYM
# RELOC-NEXT:   0x20 R_RL78_OPsub
# RELOC-NEXT:   0x20 R_RL78_ABS32U
# RELOC:        0x28 R_RL78_SYM
# RELOC-NEXT:   0x28 R_RL78_SYM
# RELOC-NEXT:   0x28 R_RL78_OPsub
# RELOC-NEXT:   0x28 R_RL78_ABS8U
# RELOC:      .rela.debug_line {
# RELOC:        R_RL78_SYM
# RELOC-NEXT:   R_RL78_SYM
# RELOC-NEXT:   R_RL78_OPsub
# RELOC-NEXT:   R_RL78_ABS16U

# DUMP-NOT:   warning
# DUMP:       DW_CFA_advance_loc: 1
# DUMP:       DW_CFA_advance_loc1: 5
# DUMP:       0x0: CFA=SPreg+4
# DUMP-NEXT:  0x1: CFA=SPreg+6
# DUMP-NEXT:  0x6: CFA=SPreg+4
# DUMP:       0x0000000000000000 1
# DUMP-NEXT:  0x0000000000000001 2
# DUMP-NEXT:  0x0000000000000005 3
# DUMP-NEXT:  0x0000000000000007 5

# NORELAX-NOT: R_RL78_SYM
# NORELAX-NOT: R_RL78_OPsub

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
