; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_DAGCombine_OR
; CHECK: addw ax, bc
; CHECK-NOT: or
define dso_local i16 @test_DAGCombine_OR(i16 noundef %0, i16 noundef %1) local_unnamed_addr {
  %3 = and i16 %0, 255
  %4 = and i16 %1, -256
  %5 = or i16 %3, %4
  ret i16 %5
}

; CHECK-LABEL: _test_DAGCombine_OR_INC
; CHECK: shl
; CHECK: inc
; CHECK-NOT: or
define dso_local i8 @test_DAGCombine_OR_INC(i8 noundef %x) {
  %sh = shl i8 %x, 1
  %res = or i8 %sh, 1
  ret i8 %res
}
