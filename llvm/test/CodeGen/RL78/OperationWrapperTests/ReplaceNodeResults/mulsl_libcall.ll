; This test verifies for the presence of the __COM_mulsl libcall.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test__mulsl:
; CHECK: ; %bb.0:
; CHECK: 	call !__COM_mulsl

define dso_local void @test__mulsl(ptr noalias nocapture writeonly sret(i64) align 2 %0, i32 noundef %1, i32 noundef %2) local_unnamed_addr #0 {
  %4 = tail call i64 @llvm.rl78.mulsl(i32 %1, i32 %2)
  store i64 %4, ptr %0, align 2
  ret void
}

declare i64 @llvm.rl78.mulsl(i32, i32) #1
