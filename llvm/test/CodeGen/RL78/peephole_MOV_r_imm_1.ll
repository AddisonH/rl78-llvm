; Test replacement of MOV X, A + MOV A, #0 with SHRW AX, 8.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: mov x, a{{[[:space:]]*}}mov a, #0
; CHECK: shrw ax, 8
define i8 @foo(i8 %0) {
  %2 = zext i8 %0 to i16
  %3 = sub i16 0, %2
  %4 = trunc i16 %3 to i8
  ret i8 %4
}
