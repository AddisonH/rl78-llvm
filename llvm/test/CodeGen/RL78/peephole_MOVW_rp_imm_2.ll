; Test replacement of MOVW AX, #1 with ONEW AX.
; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: movw ax, #1
; CHECK: onew ax
define i16 @foo() {
  ret i16 1
}
