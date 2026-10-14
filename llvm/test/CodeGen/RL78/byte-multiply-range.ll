; RUN: llc -O2 -mtriple=rl78 -stop-after=rl78-narrow-demanded,1 < %s | FileCheck %s --check-prefix=IR
; RUN: llc -O2 -mtriple=rl78 -verify-machineinstrs < %s | FileCheck %s

; y counts to a byte loaded in the loop, so it is below 255, but it is a
; word (IndVarSimplify widened it): only ScalarEvolution knows its range.
; RL78NarrowDemandedOps (its second instance, after LSR) makes it a byte for
; the multiply, which is then MULU instead of MULHU on two zero-extended
; words.

@wd = external global i8
@wdb = external global i8

; IR-LABEL: @rows(
; IR:       %[[T:.*]] = trunc i16 %y to i8
; IR-NEXT:  %[[Z:.*]] = zext i8 %[[T]] to i16
; IR-NEXT:  mul nuw nsw i16 %[[Z]], %b

; CHECK-LABEL: _rows:
; CHECK:       mulu x
; CHECK-NOT:   mulhu
; CHECK:       ret
define void @rows(ptr %p) {
entry:
  br label %loop

loop:
  %y = phi i16 [ 0, %entry ], [ %y.next, %loop ]
  %w = load i8, ptr @wdb
  %b = zext i8 %w to i16
  %m = mul nuw nsw i16 %y, %b
  %q = getelementptr inbounds i8, ptr %p, i16 %m
  store i8 0, ptr %q
  %y.next = add nuw nsw i16 %y, 1
  %n = load i8, ptr @wd
  %nz = zext i8 %n to i16
  %c = icmp ult i16 %y.next, %nz
  br i1 %c, label %loop, label %exit

exit:
  ret void
}

; Without the bound nothing is known: MULHU.
; IR-LABEL: @unbounded(
; IR-NOT:   trunc
; CHECK-LABEL: _unbounded:
; CHECK:       mulhu
define void @unbounded(ptr %p, i16 %n) {
entry:
  br label %loop

loop:
  %y = phi i16 [ 0, %entry ], [ %y.next, %loop ]
  %w = load i8, ptr @wdb
  %b = zext i8 %w to i16
  %m = mul nuw nsw i16 %y, %b
  %q = getelementptr inbounds i8, ptr %p, i16 %m
  store i8 0, ptr %q
  %y.next = add nuw nsw i16 %y, 1
  %c = icmp ult i16 %y.next, %n
  br i1 %c, label %loop, label %exit

exit:
  ret void
}
