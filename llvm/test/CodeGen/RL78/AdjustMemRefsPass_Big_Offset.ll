; Verifies the effect of the AdjustMemRefs pass in the case when
; an offset greater than 255 is used in indirect memory addressing.
; The base register is expected to be forced to BC.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define void @foo(ptr %a) {
entry:
  %arrayidx = getelementptr i8, ptr %a, i16 1000
  store i8 3, ptr %arrayidx, align 1
  ret void
}

; CHECK: mov 1000[bc], #3
