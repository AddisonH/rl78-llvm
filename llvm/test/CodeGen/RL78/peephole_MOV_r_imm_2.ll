; Test replacement of MOV A, #0 with CLRB A.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: mov a, #0
; CHECK: clrb a
define i8 @foo() {
  ret i8 0
}
