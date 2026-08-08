; This test verifies the lowering of the DIVUL intrinsic to the DIVWU instruction for S3 cores.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test__divul:
; CHECK: 	movw hl, #0
; CHECK: 	divwu ;ax, bc, de, hl, ax, bc, de, hl
; CHECK: 	nop
; CHECK: 	ret

define dso_local i32 @test__divul(i32 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = tail call i32 @llvm.rl78.divul(i32 %0, i16 %1)
  ret i32 %3
}

declare i32 @llvm.rl78.divul(i32, i16) #1
