; RUN: opt < %s -S -passes='loop-simplify,loop(loop-flatten),verify' \
; RUN:   | FileCheck %s --check-prefix=DEFAULT
; RUN: opt < %s -S -passes='loop-simplify,loop(loop-flatten),verify' \
; RUN:   -loop-flatten-version-illegal-tripcount | FileCheck %s

; 16-bit target (RL78-like): the i32 trip counts are not legal integers, and
; the index reaches the GEP through a trunc, so the overflow cannot be ruled
; out. By default the nest is left alone; with the option it is versioned on
; an i32 umul.with.overflow, and the fallback nest (only run on overflow) is
; marked not to be unrolled or jammed.

target datalayout = "e-p:16:16-i32:16-n8:16-S16"

; DEFAULT-LABEL: @sum(
; DEFAULT-NOT:   flatten

; CHECK-LABEL: @sum(
; CHECK:         %flatten.mul = call { i32, i1 } @llvm.umul.with.overflow.i32(i32 %n, i32 %n)
; CHECK:         br i1 %flatten.overflow, label %{{.*}}lver.orig{{.*}}, label
; CHECK:         br i1 %{{.*}}, label %{{.*}}, label %{{.*}}, !llvm.loop [[ORIG:![0-9]+]]
; CHECK:       [[ORIG]] = distinct !{[[ORIG]], [[UD:![0-9]+]], [[UJD:![0-9]+]]}
; CHECK:       [[UD]] = !{!"llvm.loop.unroll.disable", i32 1}
; CHECK:       [[UJD]] = !{!"llvm.loop.unroll_and_jam.disable", i32 1}
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
