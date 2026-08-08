; This test verifies the build16bitAccess function when the main register is RP2.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_build16bitAccess_RP2:
; CHECK: 	push ax
; CHECK: 	movw ax, bc
; CHECK: 	movw bc, sp
; CHECK: 	movw 804[bc], ax
; CHECK: 	movw bc, ax
; CHECK: 	pop ax

define dso_local i16 @test_build16bitAccess_RP2(i16 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = alloca [400 x i16], align 2
  call void @sink(ptr noundef nonnull %3) #3
  %4 = load i16, ptr %3, align 2
  %5 = call i16 @func(i16 noundef %0, i16 noundef %1, i16 noundef %4) #3
  ret i16 0
}

declare dso_local i16 @func(i16 noundef, i16 noundef, i16 noundef) #2
declare dso_local i16 @sink(ptr noundef nonnull) #2 

attributes #0 = { optsize }
