; This test verifies the build16bitAccess function when the main register is RP4.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_build16bitAccess_RP4:
; CHECK: 	xchw ax, de
; CHECK: 	push bc
; CHECK: 	movw bc, sp
; CHECK: 	movw ax, 804[bc]
; CHECK: 	pop bc
; CHECK: 	xchw ax, de

define dso_local i16 @test_build16bitAccess_RP4(i16 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = alloca [400 x i16], align 2
  call void @fauxi(ptr noundef nonnull %3) #3
  %4 = load i16, ptr %3, align 2
  %5 = call i16 @faux2i(i16 noundef %4, i16 noundef %0, i16 noundef %1) #3
  ret i16 0
}

declare dso_local i16 @fauxi(ptr noundef nonnull) #2 
declare dso_local i16 @faux2i(i16 noundef, i16 noundef, i16 noundef) #2

attributes #0 = { optsize }
