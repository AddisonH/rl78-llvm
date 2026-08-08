; This test verifies the build16bitAccess function when the instruction is a LOAD8_r_stack_slot
; with its main register being R0.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_8bit_load_from_R0:
; CHECK: 	push de
; CHECK: 	mov e, a
; CHECK: 	push bc
; CHECK: 	movw bc, sp
; CHECK: 	mov a, {{[0-9]+}}[bc]
; CHECK: 	pop bc
; CHECK: 	mov x, a
; CHECK: 	mov a, e
; CHECK: 	pop de

declare dso_local i8 @test(i8 noundef, i8 noundef) local_unnamed_addr #2
declare dso_local void @use_ptr(ptr noundef) local_unnamed_addr #2

define dso_local i8 @test_8bit_load_from_R0(i8 noundef %0) local_unnamed_addr #0 {
  %2 = alloca [300 x i8], align 1
  call void @use_ptr(ptr noundef nonnull %2) #3
  %3 = load i8, ptr %2, align 1
  %4 = call i8 @test(i8 noundef %3, i8 noundef %0) #3
  ret i8 %4
}

attributes #0 = { optsize }
