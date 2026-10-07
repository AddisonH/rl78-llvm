; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@a = dso_local global i16 0, align 2
@b = dso_local global i16 0, align 2

; CHECK-LABEL: _test_DAGCombine_MUL
; CHECK: mulhu ;ax, bc, ax, bc
define dso_local i32 @test_DAGCombine_MUL(i16 %a, i16 %b) {
  %za = zext i16 %a to i32
  %zb = zext i16 %b to i32
  %mul = mul i32 %za, %zb
  ret i32 %mul
}

; CHECK-LABEL: _test_DAGCombine_MULH
; CHECK: mulh ;ax, bc, ax, bc
define dso_local i32 @test_DAGCombine_MULH(i16 %a, i16 %b) {
  %sa = sext i16 %a to i32
  %sb = sext i16 %b to i32
  %mul = mul i32 %sa, %sb
  ret i32 %mul
}

; A negative constant operand must be built as a signed i16 constant
; (asserted in SelectionDAG::getConstant).
; CHECK-LABEL: _test_DAGCombine_MULH_negconst
; CHECK: movw bc, #-3
; CHECK-NEXT: mulh ;ax, bc, ax, bc
define dso_local i32 @test_DAGCombine_MULH_negconst(i16 %a) {
entry:
  %conv = sext i16 %a to i32
  %mul = mul nsw i32 %conv, -3
  ret i32 %mul
}
