; RUN: llc -mtriple=rl78 -O2 -verify-machineinstrs -stop-after=rl78-outer-loop-pointers < %s | FileCheck %s

; LSR leaves a loop with a loop inside alone. The element of %base the outer
; loop reads gets a pointer that is stepped; the access inside the inner
; loop, whose address does not change there, keeps its own.

define i32 @outer(ptr %base, ptr %other, i16 %n, i32 %lim) {
; CHECK-LABEL: define i32 @outer(
; CHECK:       outer:
; CHECK-NEXT:    [[P:%.*]] = phi ptr [ [[NEXT:%.*]], %latch ], [ %base, %entry ]
; CHECK:         [[X:%.*]] = load i32, ptr [[P]]
; CHECK:       inner:
; CHECK:         [[Q:%.*]] = getelementptr [4 x i8], ptr %other, i16 %i
; CHECK-NEXT:    store i32 {{.*}}, ptr [[Q]]
; CHECK:       latch:
; CHECK:         [[NEXT]] = getelementptr i8, ptr [[P]], i16 4
entry:
  br label %outer

outer:
  %i = phi i16 [ 0, %entry ], [ %i.next, %latch ]
  %s = phi i32 [ 0, %entry ], [ %s.next, %latch ]
  %p = getelementptr [4 x i8], ptr %base, i16 %i
  %x = load i32, ptr %p
  br label %inner

inner:
  %y = phi i32 [ %x, %outer ], [ %y.next, %inner ]
  %y.next = add i32 %y, %x
  %q = getelementptr [4 x i8], ptr %other, i16 %i
  store i32 %y.next, ptr %q
  %c = icmp slt i32 %y.next, %lim
  br i1 %c, label %inner, label %latch

latch:
  %s.next = add i32 %s, %y.next
  %i.next = add nuw nsw i16 %i, 1
  %done = icmp eq i16 %i.next, %n
  br i1 %done, label %exit, label %outer

exit:
  ret i32 %s.next
}

; An innermost loop is LSR's.
define i32 @innermost(ptr %base, i16 %n) {
; CHECK-LABEL: define i32 @innermost(
; CHECK-NOT:     outerptr
; CHECK:       exit:
entry:
  br label %loop

loop:
  %i = phi i16 [ 0, %entry ], [ %i.next, %loop ]
  %s = phi i32 [ 0, %entry ], [ %s.next, %loop ]
  %p = getelementptr [4 x i8], ptr %base, i16 %i
  %x = load i32, ptr %p
  %s.next = add i32 %s, %x
  %i.next = add nuw nsw i16 %i, 1
  %done = icmp eq i16 %i.next, %n
  br i1 %done, label %exit, label %loop

exit:
  ret i32 %s.next
}
