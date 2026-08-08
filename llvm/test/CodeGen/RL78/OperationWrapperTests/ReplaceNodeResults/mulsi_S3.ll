; This test verifies for the presence of the SMUL_LOHI instruction
; when lowering a mulsi instruction on an S3 core.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

declare i32 @llvm.rl78.mulsi(i16, i16) #1

; CHECK: _main:
; CHECK: ; %bb.0:
; CHECK: 	movw bc, #4
; CHECK: 	movw ax, #32767
; CHECK: 	mulh ;ax, bc, ax, bc

define dso_local i32 @main() local_unnamed_addr #0 {
  %1 = tail call i32 @llvm.rl78.mulsi(i16 32767, i16 4)
  ret i32 %1
}
