; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@g = dso_local local_unnamed_addr global i16 0, align 2

; This file tests both outlined and non-outlined cases in the same file.
; CHECK-LABEL: _test_available_for_outline
; CHECK: test_available_for_outline:{{.*}}; @test_available_for_outline
; CHECK: %bb.0
; CHECK-NEXT: br !_OUTLINED_FUNCTION_0 	
define dso_local void @test_available_for_outline() local_unnamed_addr #0 {
  %1 = load i16, ptr @g, align 2
  %test_available_for_outline = add nsw i16 %1, 2
  store i16 %test_available_for_outline, ptr @g, align 2
  ret void
}

; CHECK-LABEL: _test_available_for_outline2
; CHECK: test_available_for_outline2:{{.*}}; @test_available_for_outline2
; CHECK: %bb.0
; CHECK-NEXT: br !_OUTLINED_FUNCTION_0 	
define dso_local void @test_available_for_outline2() local_unnamed_addr #0 {
  %1 = load i16, ptr @g, align 2
  %test_available_for_outline = add nsw i16 %1, 2
  store i16 %test_available_for_outline, ptr @g, align 2
  ret void
}

; CHECK-LABEL: _test_nooutline
; CHECK:_test_nooutline:{{.*}}; @test_nooutline
; CHECK:; %bb.0
; CHECK-NEXT:	incw ax
; CHECK-NEXT:	ret

define dso_local i16 @test_nooutline(i16 noundef %x) local_unnamed_addr #0 {
  %add = add nsw i16 %x, 1
  ret i16 %add
}

; CHECK-LABEL: _test_nooutline2
; CHECK:_test_nooutline2:{{.*}}; @test_nooutline2
; CHECK:; %bb.0
; CHECK-NEXT:	incw ax
; CHECK-NEXT:	ret

define dso_local i16 @test_nooutline2(i16 noundef %x) local_unnamed_addr #0 {
  %add = add nsw i16 %x, 1
  ret i16 %add
}

; CHECK-LABEL: _test_available_for_outline3
; CHECK: test_available_for_outline3:{{.*}}; @test_available_for_outline3
; CHECK: %bb.0
; CHECK-NEXT: br !_OUTLINED_FUNCTION_0 	

define dso_local void @test_available_for_outline3() local_unnamed_addr #0 {
  %1 = load i16, ptr @g, align 2
  %test_available_for_outline = add nsw i16 %1, 2
  store i16 %test_available_for_outline, ptr @g, align 2
  ret void
}

attributes #0 = {optsize}
