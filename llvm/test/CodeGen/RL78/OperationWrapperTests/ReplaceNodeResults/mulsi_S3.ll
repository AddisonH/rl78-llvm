; This test verifies for the presence of the SMUL_LOHI instruction
; when lowering a mulsi instruction on an S3 core.

; RUN: llc -verify-machineinstrs -mtriple=rl78 %s -o - | FileCheck %s

declare i32 @llvm.rl78.mulsi(i16, i16) #1

; Constant operands are folded (32767 * 4 = 0x1fffc).
; CHECK: _main:
; CHECK: ; %bb.0:
; CHECK: 	onew bc
; CHECK: 	movw ax, #-4
; CHECK-NOT: mulh

; CHECK: _var:
; CHECK: ; %bb.0:
; CHECK-NEXT: 	mulh

define dso_local i32 @main() local_unnamed_addr #0 {
  %1 = tail call i32 @llvm.rl78.mulsi(i16 32767, i16 4)
  ret i32 %1
}

define dso_local i32 @var(i16 %a, i16 %b) local_unnamed_addr #0 {
  %1 = tail call i32 @llvm.rl78.mulsi(i16 %a, i16 %b)
  ret i32 %1
}
