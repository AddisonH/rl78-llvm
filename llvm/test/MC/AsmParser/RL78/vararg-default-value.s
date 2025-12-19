// RUN: llvm-mc -triple rl78 %s | FileCheck %s
.macro abc arg:vararg=nop
  \arg
.endm

.macro abcd arg0=ax arg1:vararg=bc
  movw \arg0, \arg1
.endm

.text

// CHECK: nop
  abc
// CHECK: movw ax, bc
  abcd ,
