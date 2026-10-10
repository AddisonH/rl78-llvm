; Verifies the effect of the AdjustMemRefs pass when one virtual
; register usage interval completely encloses another, and an offset
; greater than 255 is used in indirect memory addressing at the end of
; the enclosing interval.
; Visual representation assuming two virtual registers X and Y:
; [X Usage] [Y Usage] [Y Usage] [X Usage]
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@x = global ptr null, align 2

define void @foo(ptr %a, ptr %b) {
  %arrayidx = getelementptr i8, ptr %b, i16 4
  %v0 = load i8, ptr %arrayidx, align 1
  %arrayidx1 = getelementptr i8, ptr %a, i16 2
  store i8 %v0, ptr %arrayidx1, align 1
  %arrayidx2 = getelementptr i8, ptr %a, i16 6
  %v1 = load i8, ptr %arrayidx2, align 1
  %arrayidx3 = getelementptr i8, ptr %b, i16 5
  store i8 %v1, ptr %arrayidx3, align 1
  %arrayidx4 = getelementptr i8, ptr %b, i16 3
  %v2 = load i8, ptr %arrayidx4, align 1
  %v3 = load ptr, ptr @x, align 2
  %arrayidx5 = getelementptr i8, ptr %v3, i16 1000
  store i8 %v2, ptr %arrayidx5, align 1
  ret void
}

; CHECK: mov a, [hl+4]
; CHECK: mov [de+2], a
; CHECK: mov a, [de+6]
; CHECK: mov [hl+5], a
; CHECK: mov a, [hl+3]
; CHECK: mov 1000[bc], a
