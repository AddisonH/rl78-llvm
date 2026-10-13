; RUN: llc -mtriple=rl78 -O2 -verify-machineinstrs -stop-after=rl78-bias-signed-compares < %s | FileCheck %s
; RUN: llc -mtriple=rl78 -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefix=ASM

; A signed comparison costs three instructions more than an unsigned one
; (the carry is corrected by both sign bits). With the sign bit of a loop
; invariant inverted before the loop, the comparison in the loop is an
; unsigned one of the other operand with its sign bit inverted: XOR A, #0x80.

declare void @f()

define void @invariant(ptr %p, i32 %t, i16 %n) {
; CHECK-LABEL: define void @invariant(
; CHECK:       entry:
; CHECK-NEXT:    [[TB:%.*]] = xor i32 %t, -2147483648
; CHECK:       loop:
; CHECK:         [[X:%.*]] = load i32, ptr
; CHECK-NEXT:    [[XB:%.*]] = xor i32 [[X]], -2147483648
; CHECK-NEXT:    {{%.*}} = icmp ult i32 [[XB]], [[TB]]
;
; ASM-LABEL: invariant:
; ASM:         xor a, #128
; ASM:       .LBB0_1:
; ASM:         xor a, #128
; ASM-NEXT:    cmpw ax,
; ASM-NOT:     xor1
; ASM:         ret
entry:
  br label %loop
loop:
  %i = phi i16 [ 0, %entry ], [ %i.next, %latch ]
  %q = getelementptr i32, ptr %p, i16 %i
  %x = load i32, ptr %q
  %c = icmp slt i32 %x, %t
  br i1 %c, label %call, label %latch
call:
  call void @f()
  br label %latch
latch:
  %i.next = add i16 %i, 1
  %d = icmp eq i16 %i.next, %n
  br i1 %d, label %exit, label %loop
exit:
  ret void
}

; The bound does not change in the outer loop either: inverted before it,
; once for both comparisons.
define void @nested(ptr %p, i16 %t, i16 %n) {
; CHECK-LABEL: define void @nested(
; CHECK:       entry:
; CHECK-NEXT:    [[TB:%.*]] = xor i16 %t, -32768
; CHECK-NEXT:    br label %outer
; CHECK:       outer:
; CHECK-NOT:     xor i16 %t
; CHECK:       inner:
; CHECK:         [[XB:%.*]] = xor i16 %x, -32768
; CHECK-NEXT:    {{%.*}} = icmp ugt i16 [[XB]], [[TB]]
; CHECK:         [[YB:%.*]] = xor i16 %y, -32768
; CHECK-NEXT:    {{%.*}} = icmp ule i16 [[TB]], [[YB]]
entry:
  br label %outer
outer:
  %j = phi i16 [ 0, %entry ], [ %j.next, %outer.latch ]
  br label %inner
inner:
  %i = phi i16 [ 0, %outer ], [ %i.next, %inner.latch ]
  %q = getelementptr i16, ptr %p, i16 %i
  %x = load volatile i16, ptr %q
  %c = icmp sgt i16 %x, %t
  br i1 %c, label %call, label %inner.latch
call:
  %y = load volatile i16, ptr %p
  %e = icmp sle i16 %t, %y
  br i1 %e, label %inner.latch, label %call2
call2:
  call void @f()
  br label %inner.latch
inner.latch:
  %i.next = add i16 %i, 1
  %d = icmp eq i16 %i.next, %n
  br i1 %d, label %outer.latch, label %inner
outer.latch:
  %j.next = add i16 %j, 1
  %g = icmp eq i16 %j.next, %n
  br i1 %g, label %exit, label %outer
exit:
  ret void
}

; Against a constant the sign is known, and with two operands that change
; both would have to be inverted in the loop.
define void @unchanged(ptr %p, ptr %r, i16 %n) {
; CHECK-LABEL: define void @unchanged(
; CHECK-NOT:     xor
; CHECK:         icmp slt i16 %x, 1000
; CHECK-NOT:     xor
; CHECK:         icmp slt i16 %x, %y
entry:
  br label %loop
loop:
  %i = phi i16 [ 0, %entry ], [ %i.next, %latch ]
  %x = load volatile i16, ptr %p
  %c = icmp slt i16 %x, 1000
  br i1 %c, label %call, label %latch
call:
  %y = load volatile i16, ptr %r
  %e = icmp slt i16 %x, %y
  br i1 %e, label %call2, label %latch
call2:
  call void @f()
  br label %latch
latch:
  %i.next = add i16 %i, 1
  %d = icmp eq i16 %i.next, %n
  br i1 %d, label %exit, label %loop
exit:
  ret void
}

; Not for size: the inversion before the loop is as long as what it saves.
define void @size(ptr %p, i16 %t, i16 %n) optsize {
; CHECK-LABEL: define void @size(
; CHECK-NOT:     xor
; CHECK:         icmp slt i16 %x, %t
entry:
  br label %loop
loop:
  %i = phi i16 [ 0, %entry ], [ %i.next, %latch ]
  %x = load volatile i16, ptr %p
  %c = icmp slt i16 %x, %t
  br i1 %c, label %call, label %latch
call:
  call void @f()
  br label %latch
latch:
  %i.next = add i16 %i, 1
  %d = icmp eq i16 %i.next, %n
  br i1 %d, label %exit, label %loop
exit:
  ret void
}
