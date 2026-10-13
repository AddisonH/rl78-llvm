; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 
target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_DAGCombine_BRCC
; CHECK:	addw ax, bc
; CHECK-NEXT: bf a.7, $.LBB0_2
define dso_local i16 @test_DAGCombine_BRCC(i16 noundef %a, i16 noundef %b) {
  %neg = sub i16 0, %b
  %cmp = icmp slt i16 %a, %neg
  br i1 %cmp, label %t, label %f

t:
  br label %ret

f:
  br label %ret

ret:
  %r = phi i16 [ 1, %t ], [ 0, %f ]
  ret i16 %r
}
