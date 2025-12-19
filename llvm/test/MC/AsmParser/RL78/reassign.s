// RUN: llvm-mc -triple rl78 %s | FileCheck %s

	.text
bar:

	.data
.globl foo
.set   foo, bar
.globl foo
.set   foo, bar

// CHECK-NOT: invalid reassignment of non-absolute variable
