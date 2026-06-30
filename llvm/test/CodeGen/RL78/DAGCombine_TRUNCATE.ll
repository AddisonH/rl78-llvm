; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Verifies DAGCombine/ISel for TRUNCATE.
; CHECK-LABEL: _test_DAGCombine_TRUNCATE
; CHECK: movw ax, bc 
define i16 @test_DAGCombine_TRUNCATE(i32 %x) {
  %sh = lshr i32 %x, 16
  %t = trunc i32 %sh to i16
  ret i16 %t
}

; CHECK-LABEL: _test_DAGCombine_TRUNCATE_i8_ADD
; CHECK: add a
; CHECK-NOT: addw
define dso_local i8 @test_DAGCombine_TRUNCATE_i8_ADD(i16 %a, i16 %b) {
  %add16 = add i16 %a, %b
  %t = trunc i16 %add16 to i8
  ret i8 %t
}
