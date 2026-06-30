; Test replacement of MOV A, C + SHL A, #imm + MOV C, A with SHL C, #imm.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: mov a, c
; CHECK-NOT: shl a, 4
; CHECK-NOT: mov c, a
; CHECK: shl c, 4
define [3 x i8] @foo(i8 %0, i8 %1, i8 %2) {
  %4 = shl i8 %2, 4
  %5 = insertvalue [3 x i8] undef, i8 %0, 0
  %6 = insertvalue [3 x i8] %5, i8 %4, 2
  ret [3 x i8] %6
}
