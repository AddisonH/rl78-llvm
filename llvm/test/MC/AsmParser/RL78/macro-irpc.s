// RUN: llvm-mc -triple rl78 %s | FileCheck %s

.irpc foo,123
        .long \foo
.endr

// CHECK: long 1
// CHECK: long 2
// CHECK: long 3

.irpc foo,123
.irpc bar,45
        addw ax, #\foo\bar
.endr
.endr

// CHECK: addw ax, #14
// CHECK: addw ax, #15
// CHECK: addw ax, #24
// CHECK: addw ax, #25
// CHECK: addw ax, #34
// CHECK: addw ax, #35
