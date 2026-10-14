; RUN: opt -mtriple=rl78 -passes='default<O3>' -S %s | FileCheck %s
; RUN: opt -mtriple=rl78 -passes='default<O2>' -S %s | FileCheck %s --check-prefix=O2

; RL78 adds LoopFlatten to the -O3 pipeline, versioning the nest on an i32
; overflow check although i32 is not a legal integer here.

; O2-NOT:        flatten

; CHECK-LABEL: @sum(
; CHECK:         %flatten.mul = {{.*}}call { i32, i1 } @llvm.umul.with.overflow.i32(i32 %n, i32 %n)
; CHECK:         br i1 %flatten.overflow, label %outer.lver.orig, label %outer

define i32 @sum(i32 %n, ptr %c) {
entry:
  %cmp.outer = icmp eq i32 %n, 0
  br i1 %cmp.outer, label %exit, label %outer

outer:
  %i = phi i32 [ 0, %entry ], [ %i.next, %outer.latch ]
  %s.o = phi i32 [ 0, %entry ], [ %s.next, %outer.latch ]
  %row = mul i32 %i, %n
  br label %inner

inner:
  %j = phi i32 [ 0, %outer ], [ %j.next, %inner ]
  %s = phi i32 [ %s.o, %outer ], [ %s.next, %inner ]
  %idx = add i32 %row, %j
  %idx16 = trunc i32 %idx to i16
  %p = getelementptr inbounds i32, ptr %c, i16 %idx16
  %v = load i32, ptr %p, align 2
  %s.next = add i32 %s, %v
  %j.next = add nuw i32 %j, 1
  %j.done = icmp ult i32 %j.next, %n
  br i1 %j.done, label %inner, label %outer.latch

outer.latch:
  %i.next = add i32 %i, 1
  %i.done = icmp ult i32 %i.next, %n
  br i1 %i.done, label %outer, label %exit

exit:
  %r = phi i32 [ 0, %entry ], [ %s.next, %outer.latch ]
  ret i32 %r
}
