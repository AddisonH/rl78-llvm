; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Instructions "push"/"pop" are illegal to outline, no _OUTLINED_FUNCTION_0 should be present in assembly file.
; CHECK-LABEL: _test_pushPop_1
; CHECK-NOT: _OUTLINED_FUNCTION_0
; CHECK:_test_pushPop_1:{{.*}}; @test_pushPop_1
; CHECK: ; %bb.0
; CHECK-NEXT: 	push ax
; CHECK-NEXT: 	incw ax
; CHECK-NEXT: 	pop hl
; CHECK-NEXT: 	ret
define dso_local i16 @test_pushPop_1(i16 noundef %x) {
  %x.addr = alloca i16, align 2
  store i16 %x, ptr %x.addr, align 2
  %1 = load i16, ptr %x.addr, align 2
  %add = add nsw i16 %1, 1
  ret i16 %add
}

; CHECK-LABEL: _test_pushPop_2
; CHECK-NOT: _OUTLINED_FUNCTION_0
; CHECK:_test_pushPop_2:{{.*}}; @test_pushPop_2
; CHECK: ; %bb.0
; CHECK-NEXT: 	push ax
; CHECK-NEXT: 	incw ax
; CHECK-NEXT: 	pop hl
; CHECK-NEXT: 	ret
define dso_local i16 @test_pushPop_2(i16 noundef %x) {
  %x.addr = alloca i16, align 2
  store i16 %x, ptr %x.addr, align 2
  %1 = load i16, ptr %x.addr, align 2
  %add = add nsw i16 %1, 1
  ret i16 %add
}
