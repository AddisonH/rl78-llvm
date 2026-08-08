; This test verifies the MOVW_rp_stack_slot instruction when the Frame Register is RP4,
; and when the stack offset, along with the 4 bytes from the CALL instruction, fit in
; the 16 bit displacement limit.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_16bit_movw_RP4_stack_slot:
; CHECK: 	push bc
; CHECK: 	movw ax, sp
; CHECK: 	movw bc, ax
; CHECK: 	movw ax, 260[bc]
; CHECK: 	pop bc
; CHECK: 	addw ax, #266

define dso_local void @test_16bit_movw_RP4_stack_slot(i16 %0, i16 %1, i16 %2, i16 noundef %3) local_unnamed_addr #0 {
  %5 = alloca i16, align 2
  %6 = alloca i16, align 4
  %7 = alloca [255 x i8], align 1
  store i16 %3, ptr %5, align 2
  call void @sink(ptr noundef nonnull %5) #4
  call void @sink(ptr noundef nonnull %6) #4
  call void @sink(ptr noundef nonnull %7) #4
  ret void
}

declare dso_local void @sink(ptr noundef) local_unnamed_addr #2

attributes #0 = { optsize }
