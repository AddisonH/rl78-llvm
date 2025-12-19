// RUN: llvm-mc -triple rl78 --filetype=obj -g %s -o %t
// RUN: llvm-dwarfdump -a %t | FileCheck %s

.macro FOO
# 100 "./line-marker-inside-macro.s"
.endm



FOO
  mov a, #0

// CHECK:      0x0000000000000000 105 0 1 0 0 0 is_stmt
// CHECK-NEXT: 0x0000000000000002 105 0 1 0 0 0 is_stmt end_sequence
