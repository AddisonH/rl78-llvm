# RUN: llvm-mc -triple rl78 %s | FileCheck %s
# RUN: llvm-mc -triple rl78 %s | FileCheck %s
	.cg_profile a, b, 32
	.cg_profile freq, a, 11
	.cg_profile freq, b, 20

# CHECK: .cg_profile a, b, 32
# CHECK: .cg_profile freq, a, 11
# CHECK: .cg_profile freq, b, 20
