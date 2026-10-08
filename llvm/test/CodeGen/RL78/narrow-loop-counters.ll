; RUN: llc -mtriple=rl78 -O2 -stop-after=rl78-narrow-loop-counters < %s | FileCheck %s

; An i64 counter from 1 to 64, used only by its increment and the exit test,
; is rebuilt in i16.
; CHECK-LABEL: @count64(
; CHECK:      %i.n16 = phi i16 [ 1, %entry ], [ %i.next.n16, %loop ]
; CHECK:      %i.next.n16 = add i16 %i.n16, 1
; CHECK:      icmp ult i16 %i.n16, 64
; CHECK-NOT:  phi i64 [ 1
define i64 @count64(i64 %x) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 1, %entry ], [ %i.next, %loop ]
  %acc = phi i64 [ %x, %entry ], [ %acc.next, %loop ]
  %acc.next = shl i64 %acc, 1
  %i.next = add nuw nsw i64 %i, 1
  %c = icmp samesign ult i64 %i, 64
  br i1 %c, label %loop, label %exit
exit:
  ret i64 %acc.next
}

; A signed i32 counter running down from 100 compared with a signed predicate.
; CHECK-LABEL: @down(
; CHECK:      phi i16 [ 100, %entry ]
; CHECK:      icmp sgt i16 %{{.*}}, 0
define i32 @down(i32 %x) {
entry:
  br label %loop
loop:
  %i = phi i32 [ 100, %entry ], [ %i.next, %loop ]
  %acc = phi i32 [ %x, %entry ], [ %acc.next, %loop ]
  %acc.next = xor i32 %acc, 7
  %i.next = add nsw i32 %i, -1
  %c = icmp sgt i32 %i.next, 0
  br i1 %c, label %loop, label %exit
exit:
  ret i32 %acc.next
}

; The counter is used outside the loop: unchanged.
; CHECK-LABEL: @escapes(
; CHECK:      phi i32 [ 0, %entry ]
define i32 @escapes(i32 %n) {
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %i.next = add nuw nsw i32 %i, 1
  %c = icmp ult i32 %i.next, 10
  br i1 %c, label %loop, label %exit
exit:
  ret i32 %i.next
}

; The range does not fit 16 bits: unchanged.
; CHECK-LABEL: @big(
; CHECK:      phi i32 [ 0, %entry ]
define i32 @big(i32 %x) {
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %acc = phi i32 [ %x, %entry ], [ %acc.next, %loop ]
  %acc.next = xor i32 %acc, 7
  %i.next = add nuw nsw i32 %i, 1
  %c = icmp ult i32 %i.next, 100000
  br i1 %c, label %loop, label %exit
exit:
  ret i32 %acc.next
}
