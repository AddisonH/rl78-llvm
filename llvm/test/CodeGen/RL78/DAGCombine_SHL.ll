; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@a = dso_local global i16 0, align 2

; CHECK-LABEL: _test_DAGCombine_SHL 
; CHECK: clrb x
; CHECK-NOT: shl
; CHECK-NOT: shlw
; CHECK-NOT: shrw
define dso_local i16 @test_DAGCombine_SHL(i8 noundef %0) local_unnamed_addr {
  %2 = zext i8 %0 to i16
  %3 = shl nuw i16 %2, 8
  ret i16 %3
}
