; A small innermost loop with a constant count too large to unroll completely
; is unrolled in part when optimizing for speed, and left alone for size.
; RUN: opt -passes=loop-unroll -S < %s | FileCheck %s

target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: @speed(
; CHECK: store i16
; CHECK: store i16
; CHECK: br i1
define void @speed(ptr %p) {
entry:
  br label %loop

loop:
  %i = phi i16 [ 0, %entry ], [ %next, %loop ]
  %q = getelementptr inbounds i16, ptr %p, i16 %i
  %v = load i16, ptr %q
  %w = add i16 %v, 3
  store i16 %w, ptr %q
  %next = add nuw nsw i16 %i, 1
  %done = icmp eq i16 %next, 1000
  br i1 %done, label %exit, label %loop

exit:
  ret void
}

; CHECK-LABEL: @size(
; CHECK: store i16
; CHECK-NOT: store i16
; CHECK: ret void
define void @size(ptr %p) optsize {
entry:
  br label %loop

loop:
  %i = phi i16 [ 0, %entry ], [ %next, %loop ]
  %q = getelementptr inbounds i16, ptr %p, i16 %i
  %v = load i16, ptr %q
  %w = add i16 %v, 3
  store i16 %w, ptr %q
  %next = add nuw nsw i16 %i, 1
  %done = icmp eq i16 %next, 1000
  br i1 %done, label %exit, label %loop

exit:
  ret void
}
