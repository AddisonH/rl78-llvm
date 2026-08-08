; Test the LowerADDE_SUBE_rp_imm, LowerADDE_SUBE_rp_memri, LowerADDE_SUBE_rp_abs16 and
; LowerADDE_SUBE_rp_rp functions.
; Ensure ADDE_rp_imm, ADDE_rp_memri, ADDE_rp_abs16, ADDE_rp_rp instructions are lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

@xa = dso_local local_unnamed_addr global i32 0, align 2

; CHECK: _aa:
; CHECK: ; %bb.0:
; CHECK: 	addw ax, #5
; CHECK: 	sknc ;#.LBB0_2
; CHECK: ; %bb.1:
; CHECK: 	incw bc
; CHECK: .LBB0_2:
; CHECK: 	ret

define dso_local i32 @aa(i32 noundef %0) local_unnamed_addr #0 {
  %2 = add i32 %0, 5
  ret i32 %2
}


; CHECK: _ab:
; CHECK: 	movw ax, bc
; CHECK: 	xch a, x
; CHECK: 	addc a, [hl+10]
; CHECK: 	xch a, x
; CHECK: 	addc a, [hl+11]
; CHECK: 	movw bc, ax
; CHECK: 	movw ax, de

define dso_local i32 @ab(i32 noundef %0, ptr nocapture noundef readonly %1) local_unnamed_addr #1 {
  %3 = getelementptr inbounds i32, ptr %1, i16 2
  %4 = load i32, ptr %3, align 2
  %5 = add i32 %4, %0
  ret i32 %5
}


; CHECK: _ac:
; CHECK: 	movw ax, bc
; CHECK: 	xch a, x
; CHECK: 	addc a, !LOWW(_xa+2)
; CHECK: 	xch a, x
; CHECK: 	addc a, !LOWW(_xa+3)
; CHECK: 	movw bc, ax
; CHECK: 	movw ax, de

define dso_local i32 @ac(i32 noundef %0) local_unnamed_addr #2 {
  %2 = load i32, ptr @xa, align 2
  %3 = add i32 %2, %0
  ret i32 %3
}

; CHECK: _ad:
; CHECK: 	addw ax, de
; CHECK: 	movw de, ax
; CHECK: 	movw ax, [sp+0]
; CHECK: 	xch a, x
; CHECK: 	addc a, c
; CHECK: 	xch a, x
; CHECK: 	addc a, b
; CHECK: 	movw bc, ax
; CHECK: 	movw ax, de

define dso_local i32 @ad(i32 noundef %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = add i32 %0, %1
  ret i32 %3
}
