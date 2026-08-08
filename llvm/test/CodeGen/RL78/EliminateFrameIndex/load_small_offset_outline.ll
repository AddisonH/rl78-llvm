; This test verifies that LOAD / STORE instructions from the stack into an register
; will be outlined if their offsets fit inside a MOV instruction.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _OUTLINED_FUNCTION_0:
; CHECK: 	call !_sink
; CHECK: 	movw ax, [sp+8]
; CHECK: 	movw bc, ax
; CHECK: 	movw ax, [sp+10]
; CHECK: 	ret

define dso_local void @test_load_outline(i16 noundef %0) local_unnamed_addr #0 {
  %2 = alloca [4 x i8], align 1
  call void @sink(ptr noundef nonnull %2, i16 noundef %0) #4
  call void @sink(ptr noundef nonnull %2, i16 noundef %0) #4
  call void @sink(ptr noundef nonnull %2, i16 noundef %0) #4
  ret void
}

declare dso_local void @sink(ptr noundef, i16 noundef) local_unnamed_addr #2

attributes #0 = { optsize }
