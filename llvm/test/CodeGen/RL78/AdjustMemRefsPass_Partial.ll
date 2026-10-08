; Verifies the effect of the AdjustMemRefs pass in the case of
; two partially overlapping virtual register usage intervals.
; Visual representation assuming two virtual registers X and Y: 
; [X Usage] [Y Usage] [X Usage] [Y Usage]  
; RUN: llc -mtriple=rl78 -rl78-pin-address-regs=true < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define void @foo(ptr %a, ptr %b) {
  %arrayidx = getelementptr i8, ptr %a, i16 1
  store i8 2, ptr %arrayidx, align 1
  %arrayidx1 = getelementptr i8, ptr %b, i16 2
  store i8 3, ptr %arrayidx1, align 1
  %arrayidx2 = getelementptr i8, ptr %a, i16 3
  store i8 4, ptr %arrayidx2, align 1
  %arrayidx3 = getelementptr i8, ptr %b, i16 4
  store i8 5, ptr %arrayidx3, align 1
  ret void
}

; CHECK: mov [hl+1], #2
; CHECK: mov [de+2], #3
; CHECK: mov [hl+3], #4
; CHECK: mov [de+4], #5
