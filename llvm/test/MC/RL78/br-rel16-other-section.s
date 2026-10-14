# "br $!addr20" becomes "br $addr20" when the displacement fits in 8 bits. A
# target in another section has no displacement until the link: that branch
# keeps the 16-bit form (and with relaxation the linker may still shorten it).

# RUN: llvm-mc -triple=rl78 -mattr=+relax -filetype=obj %s -o %t.o
# RUN: llvm-objdump -dr %t.o | FileCheck %s
# RUN: llvm-mc -triple=rl78 -filetype=obj %s -o %t.norelax.o
# RUN: llvm-objdump -dr %t.norelax.o | FileCheck %s --check-prefix=NORELAX

# CHECK:      0: ee 00 00 br $!
# CHECK-NEXT:    R_RL78_DIR16S_PCREL far
# CHECK-NEXT:    R_RL78_RELAX
# CHECK-NEXT: 3: ef 00 br $
# CHECK-NEXT:    R_RL78_DIR8S_PCREL near

# NORELAX:      0: ee {{.. ..}} br $!
# NORELAX-NEXT:    R_RL78_DIR16S_PCREL .text.b
# NORELAX-NEXT: 3: ef 01 br $0x6 <near>

	.text
	br	$!far
	br	$!near
	nop
near:
	nop

	.section .text.b,"ax",@progbits
far:
	ret
