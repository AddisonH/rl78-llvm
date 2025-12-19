// RUN: llvm-mc -triple rl78-elf %s | FileCheck %s

.data

// CHECK: .long 3

.long (~0 >> 62)
