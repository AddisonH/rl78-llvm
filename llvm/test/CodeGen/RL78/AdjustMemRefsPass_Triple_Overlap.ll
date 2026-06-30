; Verifies the effect of the AdjustMemRefs pass in the case of
; three overlapping virtual register usage intervals.
; Visual representation assuming three virtual registers X, Y, and Z: 
; [X Usage] [Y Usage] [Z Usage] [X Usage] [Y Usage] [Z Usage]  
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define void @foo(ptr %a, ptr %b, ptr %c) {
  store i8 1, ptr %a, align 1
  store i8 2, ptr %b, align 1
  store i8 3, ptr %c, align 1
  %arrayidx3 = getelementptr i8, ptr %a, i16 1
  store i8 4, ptr %arrayidx3, align 1
  %arrayidx4 = getelementptr i8, ptr %b, i16 1
  store i8 5, ptr %arrayidx4, align 1
  %arrayidx5 = getelementptr i8, ptr %c, i16 1
  store i8 6, ptr %arrayidx5, align 1
  ret void
}

; CHECK: mov [hl], #1
; CHECK: mov [de], #2
; CHECK mov [hl], #3
; CHECK: mov [hl+1], #4
; CHECK: mov [de+1], #5
; CHECK: mov [hl+1], #6
