// RUN: llvm-mc -triple rl78 %s | FileCheck %s

.irp reg,ax,bc
        push \reg
.endr

// CHECK: push ax
// CHECK: push bc

.irp reg,ax,bc
.irp imm,4,3,5
        movw \reg, #\imm
.endr
.endr

// CHECK: movw ax, #4
// CHECK: movw ax, #3
// CHECK: movw ax, #5
// CHECK: movw bc, #4
// CHECK: movw bc, #3
// CHECK: movw bc, #5
