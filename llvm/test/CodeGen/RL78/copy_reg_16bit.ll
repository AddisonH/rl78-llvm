; RUN: llc -march=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"


; CHECK-LABEL: _test_AX_rp:
; CHECK: movw ax, bc
define dso_local i16 @test_AX_rp(i16 noundef %0, i16 noundef returned %1) {
  ret i16 %1
}

; CHECK-LABEL: _test_rp_AX:
; CHECK: movw bc, ax
define dso_local void @test_rp_AX(i16 noundef %0) {
  tail call void @callee(i16 noundef 0, i16 noundef %0) 
  ret void
}

; CHECK-LABEL: _test_rp_rp:
; CHECK: push bc
; CHECK-NEXT: pop hl
define dso_local i16 @_test_rp_rp(i16 noundef %0, i16 noundef %1, i16 noundef %2, i16 noundef %3) {
  tail call void @callee1(i16 noundef %1, i16 noundef %2, i16 noundef %3) 
  %5 = add i16 %1, %3
  ret i16 %5
}

declare dso_local void @callee(i16 noundef, i16 noundef) 
declare dso_local void @callee1(i16 noundef, i16 noundef, i16 noundef) 
