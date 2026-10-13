; Test replacement of MOVW AX, #-1 with CLRW AX + DECW AX.
; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: movw ax, #-1
; CHECK: clrw ax
; CHECK-NEXT: decw ax
define i16 @foo() #0 {
  ret i16 -1
}

attributes #0 = { optsize  }
