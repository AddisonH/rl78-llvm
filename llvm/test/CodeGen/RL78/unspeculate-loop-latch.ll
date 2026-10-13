; RUN: llc -mtriple=rl78 -O2 -verify-machineinstrs -stop-after=rl78-unspeculate-loop-latch < %s | FileCheck %s

; Loop rotation leaves "while (x < t) x += p;" as one block that adds before
; it tests. With 32-bit values the loop tests before its first iteration
; instead; 16-bit ones stay as they are.

define i32 @wide(i32 %x0, i32 %t, i32 %p) {
; CHECK-LABEL: define i32 @wide(
; CHECK:       entry:
; CHECK-NEXT:    [[C0:%.*]] = icmp slt i32 %x0, %t
; CHECK-NEXT:    br i1 [[C0]], label %loop, label %exit
; CHECK:       loop:
; CHECK-NEXT:    [[X:%.*]] = phi i32 [ %x0, %entry ], [ [[NEXT:%.*]], %loop ]
; CHECK-NEXT:    [[NEXT]] = add nsw i32 [[X]], %p
; CHECK-NEXT:    [[C:%.*]] = icmp slt i32 [[NEXT]], %t
; CHECK-NEXT:    br i1 [[C]], label %loop, label %exit
; CHECK:       exit:
; CHECK-NEXT:    [[OUT:%.*]] = phi i32 [ %x0, %entry ], [ [[NEXT]], %loop ]
; CHECK-NEXT:    ret i32 [[OUT]]
entry:
  br label %loop

loop:
  %x = phi i32 [ %x0, %entry ], [ %next, %loop ]
  %c = icmp slt i32 %x, %t
  %next = add nsw i32 %x, %p
  br i1 %c, label %loop, label %exit

exit:
  ret i32 %x
}

define i16 @narrow(i16 %x0, i16 %t, i16 %p) {
; CHECK-LABEL: define i16 @narrow(
; CHECK:       entry:
; CHECK-NEXT:    br label %loop
; CHECK:       loop:
; CHECK-NEXT:    [[X:%.*]] = phi i16
; CHECK-NEXT:    [[C:%.*]] = icmp slt i16 [[X]], %t
entry:
  br label %loop

loop:
  %x = phi i16 [ %x0, %entry ], [ %next, %loop ]
  %c = icmp slt i16 %x, %t
  %next = add nsw i16 %x, %p
  br i1 %c, label %loop, label %exit

exit:
  ret i16 %x
}

; The store is not for the next iteration only: it has to run as often as it
; did.
define i32 @side_effect(i32 %x0, i32 %t, i32 %p, ptr %q) {
; CHECK-LABEL: define i32 @side_effect(
; CHECK:       entry:
; CHECK-NEXT:    br label %loop
entry:
  br label %loop

loop:
  %x = phi i32 [ %x0, %entry ], [ %next, %loop ]
  %c = icmp slt i32 %x, %t
  %next = add nsw i32 %x, %p
  store i32 %next, ptr %q
  br i1 %c, label %loop, label %exit

exit:
  ret i32 %x
}
