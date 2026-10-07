; RUN: opt -S -passes=loop-reduce < %s | FileCheck %s
; On RL78 (16-bit) LSR tracks 32-bit induction variables, so a 32-bit loop
; counter whose uses are truncated to 16-bit addresses is strength-reduced:
; the k * n index becomes a pointer stepping by 2 * n, with no multiply.

; CHECK-LABEL: @column_sum(
; CHECK:       loop:
; CHECK:         %lsr.iv = phi ptr
; CHECK-NOT:     mul
; CHECK:         load i16, ptr %lsr.iv
; CHECK:         getelementptr i8, ptr %lsr.iv
; CHECK:         br i1
target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define i16 @column_sum(ptr %b, i32 %n, i32 %j) {
entry:
  %z = icmp eq i32 %n, 0
  br i1 %z, label %exit, label %loop

loop:
  %k = phi i32 [ 0, %entry ], [ %k.next, %loop ]
  %s = phi i16 [ 0, %entry ], [ %s.next, %loop ]
  %kn = mul i32 %k, %n
  %idx32 = add i32 %kn, %j
  %idx = trunc i32 %idx32 to i16
  %p = getelementptr inbounds i16, ptr %b, i16 %idx
  %v = load i16, ptr %p, align 2
  %s.next = add i16 %s, %v
  %k.next = add nuw i32 %k, 1
  %c = icmp ult i32 %k.next, %n
  br i1 %c, label %loop, label %exit

exit:
  %r = phi i16 [ 0, %entry ], [ %s.next, %loop ]
  ret i16 %r
}
