; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@a = dso_local global i16 0, align 2
@b = dso_local global i16 0, align 2

; CHECK-LABEL: test_DAGCombine_UREM
; CHECK: 	divwu
; CHECK: movw ax, de 
; CHECK-NEXT: push hl
; CHECK-NEXT: pop bc

define i32 @test_DAGCombine_UREM(i32 %a, i32 %b) {
  %r = urem i32 %a, %b
  ret i32 %r
}
