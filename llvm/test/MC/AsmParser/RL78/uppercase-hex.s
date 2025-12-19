# RUN: llvm-mc -triple rl78 %s | FileCheck %s

foo:
.short 	0X1
# CHECK: .short 1
.short 	0B1
# CHECK: .short 1
