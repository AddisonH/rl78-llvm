; This test verifies the presence of the __COM_remul libcall of an intrinsic without a chain.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test__remul:
; CHECK: ; %bb.0:
; CHECK: 	call !__COM_remul
; CHECK: 	ret
define dso_local i16 @test__remul(i32 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = tail call i16 @llvm.rl78.remul(i32 %0, i16 %1)
  ret i16 %3
}

declare i16 @llvm.rl78.remul(i32, i16) #1
