; Test replacement of MOVW AX, #0 with CLRW AX.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: movw ax, #0
; CHECK: clrw ax
define i16 @foo() {
  ret i16 0
}
