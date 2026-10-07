; Test the LowerShift_Or_LowerRotate_rp_rp function.
; Ensure the SHLW_rp_rp instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _ab:
; CHECK: 	mov a, [de]
; CHECK: 	mov c, a
; CHECK: 	cmp0 c
; CHECK: 	bnz $.LBB0_2
; CHECK: ; %bb.1:
; CHECK: 	movw ax, [sp+0]
; CHECK: 	br $.LBB0_4

; CHECK: .LBB0_2:
; CHECK: 	movw ax, [sp+0]

; CHECK: .LBB0_3:
; CHECK-NEXT: 	shlw ax, 1
; CHECK-NEXT: 	dec c
; CHECK-NEXT: 	bnz $.LBB0_3

define dso_local void @ab(ptr nocapture noundef %0, ptr nocapture noundef readonly %1) local_unnamed_addr #0 {
  %3 = load i16, ptr %0, align 1
  %4 = load i16, ptr %1, align 1
  %5 = shl i16 %3, %4
  store i16 %5, ptr %0, align 1
  ret void
}
