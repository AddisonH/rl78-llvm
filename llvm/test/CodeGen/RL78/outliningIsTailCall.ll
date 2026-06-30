; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define dso_local i16 @bar(i16 noundef %0) local_unnamed_addr #0 {
  %2 = add nsw i16 %0, 1
  ret i16 %2
}

; Instructions TailCall is legal to outline
; CHECK: _test_tailCall:{{.*}}; @test_tailCall
; CHECK: ; %bb.0:
; CHECK-NEXT: br !_OUTLINED_FUNCTION_0
define dso_local i16 @test_tailCall(i16 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i16 @bar(i16 noundef %0) 
  %3 = add nsw i16 %2, 2
  ret i16 %3
}


; CHECK: _test_tailCall2:{{.*}}; @test_tailCall2
; CHECK: ; %bb.0:
; CHECK-NEXT: br !_OUTLINED_FUNCTION_0
define dso_local i16 @test_tailCall2(i16 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i16 @bar(i16 noundef %0) 
  %3 = add nsw i16 %2, 2
  ret i16 %3
}

attributes #0 = { optsize }
