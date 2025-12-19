# RUN: llvm-mc -triple rl78 %s | FileCheck %s

	.extern	start

# CHECK: .org 1024, 0
. = 0x400
	movw	ax, #(0x400 + 0x100)



# CHECK: .org 1280, 0
. = 0x400 + 0x100
	.long	(3*8)-1

# CHECK: .org 1296, 0
. = 0x400 + 0x110
	.long	0x1


# CHECK: .org 1360, 0
. = 0x400 + 0x150
	.long	0x2


. = 0x300
