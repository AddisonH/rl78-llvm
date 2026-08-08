; Test the LowerRotate_r_imm and LowerRotate16_rp_imm functions.
; Ensure ROTL_r_imm and ROTL16_r_imm instructions are lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _ac:
; CHECK: 	ror a, 1
; CHECK: 	ror a, 1

define dso_local i8 @ac(i8 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i8 @llvm.fshl.i8(i8 %0, i8 %0, i8 6)
  ret i8 %2
}


; CHECK: _af:
; CHECK: 	movw bc, ax
; CHECK: 	shlw bc, 4
; CHECK: 	shrw ax, 12
; CHECK: 	addw ax, bc

define dso_local i16 @af(i16 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i16 @llvm.fshl.i16(i16 %0, i16 %0, i16 4)
  ret i16 %2
}

declare i8 @llvm.fshl.i8(i8, i8, i8) #1

declare i16 @llvm.fshl.i16(i16, i16, i16) #1
