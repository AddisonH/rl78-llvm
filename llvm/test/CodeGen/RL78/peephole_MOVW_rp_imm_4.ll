; Test replacement of MOVW AX, #0x101 with ONEB A + ONEB X.
; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: movw ax, #257
; CHECK: oneb a
; CHECK-NEXT: oneb x
define i16 @foo() #0 {
  ret i16 257
}

attributes #0 = { optsize  }
