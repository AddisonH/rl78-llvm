# RUN: llvm-mc -triple rl78 %s > %t
# RUN: FileCheck < %t %s

// CHECK: .globl $foo
.globl $foo
// CHECK: .long ($foo)
.long ($foo)
