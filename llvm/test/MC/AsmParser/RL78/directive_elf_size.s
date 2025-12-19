# RUN: llvm-mc -triple rl78 %s | FileCheck %s

a:
	ret
.Lt:
# CHECK: .size	a, .Lt-a
	.size	a, .Lt-a

