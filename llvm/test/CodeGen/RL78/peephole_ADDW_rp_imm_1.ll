; Test replacement of ADDW AX, #2 with 2 x INCW AX.
; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: addw ax, #2
; CHECK: incw ax
; CHECK-NEXT: incw ax
define i16 @foo(i16 %x) {
  %add = add i16 %x, 2
  ret i16 %add
}
