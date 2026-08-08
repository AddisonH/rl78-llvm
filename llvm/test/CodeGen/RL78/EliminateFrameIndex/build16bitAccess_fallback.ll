; This test verifies the general fallback inside the build16bitAccess function.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_8bit_R0_store:
; CHECK:	push ax
; CHECK:	mov a, x
; CHECK:	push bc
; CHECK:	movw bc, sp
; CHECK:	mov {{[0-9]+}}[bc], a
; CHECK:	pop bc
; CHECK:	pop ax

define i8 @test_8bit_R0_store(i8 %0, i8 %1) {
  %3 = alloca [300 x i8]
  call void @use_ptr(ptr %3)
  %4 = getelementptr i8, ptr %3, i8 %0
  store i8 %1, ptr %4
  %5 = load i8, ptr %3
  ret i8 %5
}

declare void @use_ptr(ptr noundef)

attributes #0 = { optsize }
