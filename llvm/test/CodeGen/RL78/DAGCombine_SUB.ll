; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_DAGCombine_SUB 
; CHECK: shlw ax, 15
; CHECK: sarw ax, 15
; CHECK-NOT: sub
define dso_local i16 @test_DAGCombine_SUB(i16 noundef %0) local_unnamed_addr {
  %2 = and i16 %0, 1
  %3 = sub nsw i16 0, %2
  ret i16 %3
}

; CHECK-LABEL: _test_DAGCombine_SUB_i8
; CHECK: shl
; CHECK: sar
; CHECK-NOT: sub
define dso_local i8 @test_DAGCombine_SUB_i8(i8 noundef %0) local_unnamed_addr {
  %2 = and i8 %0, 1
  %3 = sub nsw i8 0, %2
  ret i8 %3
}
