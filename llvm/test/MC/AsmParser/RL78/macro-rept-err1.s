// RUN: not llvm-mc -triple rl78 %s 2> %t
// RUN: FileCheck < %t %s

.endr

// CHECK: unmatched '.endr' directive
