; Test the LowerDIVWU function.
; Ensure the UDIVREM32_r_r instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _aa:
; CHECK: 	movw hl, ax
; CHECK: 	movw ax, [sp+8]
; CHECK: 	movw [sp+0], ax
; CHECK: 	movw ax, [sp+6]
; CHECK: 	movw de, ax
; CHECK: 	movw ax, hl
; CHECK: 	xchw ax, hl
; CHECK: 	movw ax, [sp+0]
; CHECK: 	xchw ax, hl
; CHECK: 	divwu ;ax, bc, de, hl, ax, bc, de, hl

define dso_local i32 @aa(i32 noundef %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = udiv i32 %0, %1
  ret i32 %3
}
