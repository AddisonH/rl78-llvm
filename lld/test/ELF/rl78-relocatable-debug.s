# REQUIRES: rl78
## A label difference in a debug section is a sequence of relocations:
## two R_RL78_SYM push the addresses, R_RL78_OPsub subtracts and
## R_RL78_ABS32U stores the result. A relocatable link keeps the whole
## sequence for the final link instead of applying the last two. (The
## assembler leaves the difference to the linker because a call that may be
## relaxed lies between the labels.)

# RUN: llvm-mc -filetype=obj -triple=rl78 -mattr=+relax %s -o %t.o
# RUN: ld.lld -r %t.o -o %t.ro
# RUN: llvm-readelf -r %t.ro | FileCheck %s --check-prefix=REL
# RUN: ld.lld --no-relax %t.ro -o %t --defsym=_start=0 --defsym=ext=0x200
# RUN: llvm-objdump -s -j .debug_info %t | FileCheck %s

# REL:      .rela.debug_info
# REL:      R_RL78_SYM
# REL-NEXT: R_RL78_SYM
# REL-NEXT: R_RL78_OPsub
# REL-NEXT: R_RL78_ABS32U

# CHECK: 05000000

	.text
begin:
	nop
	call	!!ext
end:

	.section .debug_info,"",@progbits
	.long	end - begin
