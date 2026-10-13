; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@g = dso_local local_unnamed_addr global i16 0, align 2

; CHECK-LABEL: _test_identicalFunction1
; CHECK: br !_OUTLINED_FUNCTION_0
define dso_local void @test_identicalFunction1() local_unnamed_addr #0 {
  %1 = load i16, ptr @g, align 2
  %add1 = add nsw i16 %1, 2
  store i16 %add1, ptr @g, align 2
  ret void
}

; CHECK-LABEL: _test_identicalFunction2
; CHECK: br !_OUTLINED_FUNCTION_0
define dso_local void @test_identicalFunction2() local_unnamed_addr #0 {
  %1 = load i16, ptr @g, align 2
  %add1 = add nsw i16 %1, 2
  store i16 %add1, ptr @g, align 2
  ret void
}

attributes #0 = {optsize}
