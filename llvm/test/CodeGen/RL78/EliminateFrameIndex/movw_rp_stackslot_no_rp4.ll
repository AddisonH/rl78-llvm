; This test verifies the MOVW_rp_sp emitted when a MOVW_rp_stack_slot instruction does
; not have RP4 as its FrameReg.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_movw_rp_sp:
; CHECK: 	movw ax, sp

define dso_local noalias nonnull ptr @test_movw_rp_sp() local_unnamed_addr #0 {
  %1 = alloca i16, align 2
  %2 = getelementptr inbounds i16, ptr %1, i16 5
  ret ptr %2
}
