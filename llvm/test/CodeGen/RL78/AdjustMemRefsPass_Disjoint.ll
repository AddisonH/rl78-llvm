; Verifies the effect of the AdjustMemRefs pass in the case of
; two disjoint virtual register usage intervals.
; Visual representation assuming two virtual registers X and Y: 
; [X Usage] [Y Usage] 
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define void @foo(ptr %a, ptr %b) {
  %a1 = getelementptr i8, ptr %a, i16 1
  store i8 3, ptr %a1, align 1
  %b2 = getelementptr i8, ptr %b, i16 2
  store i8 4, ptr %b2, align 1
  ret void
}

; CHECK: mov [hl+1], #3
; CHECK: push bc
; CHECK: pop hl
; CHECK: mov [hl+2], #4
