; Test replacement of MOV A, #1 with ONEB A.
; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: mov a, #1
; CHECK: oneb a
define i8 @foo() {
  ret i8 1
}
