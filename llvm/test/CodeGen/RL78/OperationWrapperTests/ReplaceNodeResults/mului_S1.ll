; This test verifies for the presence of the __COM_mului libcall for S1 cores.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test__mului:
; CHECK: ; %bb.0:
; CHECK:  call !__COM_mului

define dso_local i32 @test__mului(i16 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = tail call i32 @llvm.rl78.mului(i16 %0, i16 %1)
  ret i32 %3
}

declare i32 @llvm.rl78.mului(i16, i16) #1

attributes #0 = { "target-cpu"="RL78_S1" }
