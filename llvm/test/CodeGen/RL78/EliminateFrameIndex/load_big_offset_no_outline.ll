; This test verifies that LOAD / STORE instructions will not be outlined when
; their offsets, along with the 4 bytes from the CALL instruction, cannot fit inside
; the 8 bit displacement limit.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_no_outline_load:
; CHECK: 	movw [sp+252], ax
; CHECK: 	call !_OUTLINED_FUNCTION_0
; CHECK: 	movw ax, [sp+252]
; CHECK: 	call !_OUTLINED_FUNCTION_0
; CHECK: 	movw ax, [sp+252]
; CHECK: 	call !_sink

define dso_local void @test_no_outline_load(i16 noundef %0) local_unnamed_addr #0 {
  %2 = alloca [250 x i8], align 1
  call void @sink(ptr noundef nonnull %2, i16 noundef %0) #4
  call void @sink(ptr noundef nonnull %2, i16 noundef %0) #4
  call void @sink(ptr noundef nonnull %2, i16 noundef %0) #4
  ret void
}

declare dso_local void @sink(ptr noundef, i16 noundef) local_unnamed_addr #2

attributes #0 = { optsize }
