; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@g = dso_local local_unnamed_addr global i16 0, align 2

; Instructions Terminator is illegal to outline, no _OUTLINED_FUNCTION_0 should be present in assembly file. 
; CHECK-LABEL: _test_terminator
; CHECK: _test_terminator:{{.*}}; @test_terminator
; CHECK: ; %bb.0
; CHECK-NEXT:	incw !LOWW(_g)
; CHECK-NEXT:	ret
define dso_local void @test_terminator()  {
  %1 = load i16, ptr @g, align 2
  %add = add nsw i16 %1, 1
  store i16 %add, ptr @g, align 2
  ret void
}

; CHECK-LABEL: _test_terminator2
; CHECK: _test_terminator2:{{.*}}; @test_terminator2
; CHECK: ; %bb.0
; CHECK-NEXT:	incw !LOWW(_g)
; CHECK-NEXT:	ret
define dso_local void @test_terminator2() {
  %1 = load i16, ptr @g, align 2
  %add = add nsw i16 %1, 1
  store i16 %add, ptr @g, align 2
  ret void
}

; CHECK-NOT: !_OUTLINED_FUNCTION_0
