; Test replacement of XOR1 CY with ADDW AX, AX.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: xor1 cy
; CHECK: %bb.0:
; CHECK-NEXT: addw ax, ax
define i16 @foo(i16 %a, i16 %b) {
bb0:
  %cmp = icmp sgt i16 %a, 0
  br i1 %cmp, label %bb1, label %bb2

bb1:
  tail call void @aux()
  br label %bb2

bb2:
  ret i16 12
}

declare void @aux(...)
