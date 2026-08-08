; The divul_1 test searches for the same libcall as this one (__COM_uldiv) but
; this one gets emitted immediately because it has target CPU set to S1.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test__divul:
; CHECK: ; %bb.0:
; CHECK: 	call !__COM_uldiv

define dso_local i32 @test__divul(i32 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = tail call i32 @llvm.rl78.divul(i32 %0, i16 %1)
  ret i32 %3
}

declare i32 @llvm.rl78.divul(i32, i16) #1

attributes #0 = { "target-cpu"="RL78_S1" }
