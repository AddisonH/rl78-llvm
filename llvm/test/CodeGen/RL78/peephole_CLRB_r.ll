; Test replacement of MOV X, A + CLRB A with SHRW AX, 8.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: mov x, a
; CHECK-NOT: clrb a
; CHECK: shrw ax, 8
define i16 @foo(i8 noundef %0) {
  %2 = zext i8 %0 to i16
  ret i16 %2
}
