; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @llvm.trap()
declare void @llvm.rl78.nop() #1

; CHECK-LABEL: _test_DagCombine_TRAPInline
; CHECK: ;APP
; CHECK-NEXT: ;NO_APP
; CHECK-NOT: call !_abort
define void @test_DagCombine_TRAPInline() #0 {
entry:
  call void asm sideeffect "", ""()
  call void @llvm.trap()
  unreachable
}

attributes #0 = { "inline_asm" }
attributes #1 = { nounwind }
