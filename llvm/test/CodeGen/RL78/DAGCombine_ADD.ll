; RUN: llc -mtriple=rl78 < %s | FileCheck %s --check-prefix=ADD8
; RUN: llc -mtriple=rl78 -mattr=+far-data < %s | FileCheck %s --check-prefix=HI16

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; ADD8-LABEL: _test_DAGCombine_ADD:
; ADD8: inc a
; ADD8-NEXT: shl a, 1
define dso_local i8 @test_DAGCombine_ADD(i8 noundef %0) {
  %2 = shl i8 %0, 1
  %3 = add i8 %2, 2
  ret i8 %3
}

; HI16-LABEL: _test_DAGCombine_ADD_HI16:
; HI16: movw bc, #LOWW(_u)
; HI16-NEXT:mov es, #HIGHW(_u)
; HI16-NEXT:addw ax, bc

@u = internal global [32 x i8] zeroinitializer, align 2

define void @test_DAGCombine_ADD_HI16(i16 %idx) {
  %p = getelementptr inbounds i8, ptr @u, i16 %idx
  store i16 0, ptr %p, align 1
  ret void
}
