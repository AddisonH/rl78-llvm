; Test replacement of MOVW AX, #0x100 with ONEB A + CRLB X.
; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: movw ax, #256
; CHECK: oneb a
; CHECK-NEXT: clrb x
define i16 @foo() #0 {
  ret i16 256
}

attributes #0 = { optsize  }
