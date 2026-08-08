; This test verifies the MOVW_rp_stack_slot instruction when the Frame Register is RP4,
; with a stack offset that can fit in the 8 bit displacement limit.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_16bit_movw_rp_stack_slot:
; CHECK: 	movw ax, sp
; CHECK: 	addw ax, #4

define dso_local void @test_16bit_movw_rp_stack_slot(i16 %0, i16 %1, i16 %2, i16 noundef %3) local_unnamed_addr #0 {
  %5 = alloca i16, align 2
  store i16 %3, ptr %5, align 2
  call void @sink(ptr noundef nonnull %5) #4
  ret void
}

declare dso_local void @sink(ptr noundef) local_unnamed_addr #2

attributes #0 = { optsize }
