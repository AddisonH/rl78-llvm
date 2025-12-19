// RUN: not llvm-mc -triple rl78 %s 2> %t
// RUN: FileCheck < %t %s

.rept 3
.long

// CHECK: no matching '.endr' in definition
