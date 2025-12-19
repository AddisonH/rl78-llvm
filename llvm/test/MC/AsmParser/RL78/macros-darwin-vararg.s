// RUN: llvm-mc -triple rl78 %s 2>&1 | FileCheck %s

.macro abc a b:vararg
.globl "\a, \b"
.endm

// CHECK: .globl "zed0, zed1, zed2"
abc zed0, zed1, zed2

.purgem abc

.macro ifcc arg:vararg
.if cc
            \arg
.endif
.endm

.macro ifcc2 arg0 arg1:vararg
.if cc
            movw \arg0, \arg1
.endif
.endm

.macro ifcc3 arg0, arg1:vararg
.if cc
            movw \arg0, \arg1
.endif
.endm

.macro ifcc4 arg0, arg1:vararg
.if cc
            movw \arg1, \arg0
.endif
.endm

.text

// CHECK: movw sp, ax
// CHECK: subw sp, #4
// CHECK: movw ax, bc
// CHECK: movw ax, bc
// CHECK: movw ax, de
// CHECK: movw ax, hl
// CHECK: movw hl, ax
// CHECK: movw bc, ax
.set cc,1
  ifcc  movw sp, ax
        subw sp, #4

  ifcc2 ax, bc
  ifcc2 ax, bc
  ifcc3 ax, de
  ifcc3 ax, hl
  ifcc4 ax, hl  ;test
  ifcc4 ax, bc  ;test

// CHECK-NOT: movw
// CHECK: subw sp, #2
.set cc,0
  ifcc  movw,    sp, ax
        subw sp, #2

.macro abc arg:vararg=nop
  \arg
.endm

.macro abcd arg0=ax, arg1:vararg=bc
  movw \arg0, \arg1
.endm

.text

// CHECK: nop
  abc
// CHECK: movw ax, bc
  abcd ,

.macro .make_macro start, end, name, body:vararg
\start \name
\body
\end
.endmacro
