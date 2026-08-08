; This test verifies for the presence of the __COM_macui libcall.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test__macui:
; CHECK: ; %bb.0:
; CHECK: 	call !__COM_macui

define dso_local i32 @test__macui(i16 noundef %0, i16 noundef %1, i32 noundef %2) local_unnamed_addr #0 {
  %4 = tail call i32 @llvm.rl78.macui(i16 %0, i16 %1, i32 %2)
  ret i32 %4
}

declare i32 @llvm.rl78.macui(i16, i16, i32) #1
