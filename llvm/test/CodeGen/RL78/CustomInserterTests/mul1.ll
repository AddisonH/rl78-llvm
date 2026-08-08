; Test the LowerMULDIV16, LowerMUL8Zext16, LowerMUL8 functions.
; Ensure MUL32_zext_r_r, MULU_zext_16_r_r, MUL8_r_r, MACH_CG instructions are lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _aa:
; CHECK: 	mulhu ;ax, bc, ax, bc

define dso_local i32 @aa(i16 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = zext i16 %0 to i32
  %4 = zext i16 %1 to i32
  %5 = mul nuw i32 %3, %4
  ret i32 %5
}


; CHECK: _ac:
; CHECK: 	mulu x ; ax, a, x

define dso_local i16 @ac(i8 noundef %0, i8 noundef %1) local_unnamed_addr #0 {
  %3 = zext i8 %0 to i16
  %4 = zext i8 %1 to i16
  %5 = mul nuw i16 %3, %4
  ret i16 %5
}


; CHECK: _ad:
; CHECK: 	mulu x ; x trunk to i8
; CHECK: 	mov a, x

define dso_local i8 @ad(i8 noundef %0, i8 noundef %1) local_unnamed_addr #0 {
  %3 = mul i8 %0, %1
  ret i8 %3
}


; CHECK: _ae:
; CHECK: 	movw ax, de
; CHECK: 	mach ; macr, ax, bc
; CHECK: 	movw ax, !0xffff0
; CHECK: 	xchw ax, bc
; CHECK: 	movw ax, !0xffff2
; CHECK: 	xchw ax, bc

define dso_local i32 @ae(i16 noundef %0, i16 noundef %1, i32 noundef %2) local_unnamed_addr #0 {
  %4 = sext i16 %0 to i32
  %5 = sext i16 %1 to i32
  %6 = mul nsw i32 %4, %5
  %7 = add nsw i32 %6, %2
  ret i32 %7
}
