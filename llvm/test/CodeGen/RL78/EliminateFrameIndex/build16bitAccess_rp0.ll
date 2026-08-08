; This test verifies the build16bitAccess function when the main register is RP0.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_build16bitAccess_RP0:
; CHECK: 	push bc
; CHECK: 	movw bc, sp
; CHECK: 	mov 402[bc], a
; CHECK: 	pop bc

; CHECK: 	push bc
; CHECK: 	movw bc, sp
; CHECK: 	mov a, 402[bc]
; CHECK: 	pop bc

define dso_local i8 @test_build16bitAccess_RP0(i8 noundef %0) local_unnamed_addr #0 {
  %2 = alloca [400 x i8], align 2
  call void @sink(ptr noundef nonnull %2) #3
  %3 = load i8, ptr %2, align 2
  %4 = call i8 @func(i8 noundef %0, i8 noundef %3) #3
  ret i8 0
}

declare dso_local i8 @sink(ptr noundef nonnull) #2 
declare dso_local i8 @func(i8 noundef, i8 noundef) #2

attributes #0 = { optsize }
