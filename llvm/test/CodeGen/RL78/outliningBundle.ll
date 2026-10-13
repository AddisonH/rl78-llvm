; RUN: llc -verify-machineinstrs -mtriple=rl78 -enable-machine-outliner < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Instruction bundle is illegal to outline, no _OUTLINED_FUNCTION_0 should be present in assembly file. 
; CHECK-LABEL: _test_bundle_1
; CHECK-NOT: _OUTLINED_FUNCTION_0
; CHECK: _test_bundle_1:{{.*}}; @test_bundle_1
define dso_local i16 @test_bundle_1(i16 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = mul i16 %0, %1
  ret i16 %3
}

; CHECK-LABEL: _test_bundle_2
; CHECK-NOT: _OUTLINED_FUNCTION_0
; CHECK: _test_bundle_2:{{.*}}; @test_bundle_2
define dso_local i16 @test_bundle_2(i16 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = mul i16 %0, %1
  ret i16 %3
}

attributes #0 = { "target-cpu"="RL78_S2" }
