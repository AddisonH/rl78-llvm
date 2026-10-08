; RUN: llc -O2 -mtriple=rl78 -stop-after=rl78-narrow-demanded < %s | FileCheck %s
; The narrowing pass leaves induction steps alone: only the low half of k is
; demanded (the loop exits on a separate counter), but zext(trunc(k) + 2) is
; no longer an AddRec, and LSR would lose the IV.

; CHECK-LABEL: @every_other(
; CHECK: %k = phi i32
; CHECK: %k.next = add i32 %k, 2
define i16 @every_other(ptr %a, i16 %cnt) {
entry:
  br label %loop

loop:
  %k = phi i32 [ 0, %entry ], [ %k.next, %loop ]
  %n = phi i16 [ %cnt, %entry ], [ %n.next, %loop ]
  %s = phi i16 [ 0, %entry ], [ %s.next, %loop ]
  %idx = trunc i32 %k to i16
  %p = getelementptr inbounds i16, ptr %a, i16 %idx
  %v = load i16, ptr %p, align 2
  %s.next = add i16 %s, %v
  %k.next = add i32 %k, 2
  %n.next = add i16 %n, -1
  %c = icmp eq i16 %n.next, 0
  br i1 %c, label %exit, label %loop

exit:
  ret i16 %s.next
}

; An unrolled loop indexes with (k | 1) * n. Narrowing keeps `disjoint` on the
; or: SCEV only treats a disjoint or as an add, and without it (k | 1) * n is
; not an add recurrence, so LSR cannot strength-reduce the multiply.

; CHECK-LABEL: @unrolled_stride(
; CHECK: or disjoint i16
define i32 @unrolled_stride(ptr %b, i32 %n) {
entry:
  br label %loop

loop:
  %k = phi i32 [ 0, %entry ], [ %k.next, %loop ]
  %s = phi i32 [ 0, %entry ], [ %s.next, %loop ]
  %k1 = or disjoint i32 %k, 1
  %m = mul i32 %k1, %n
  %idx = trunc i32 %m to i16
  %p = getelementptr inbounds i16, ptr %b, i16 %idx
  %v = load i16, ptr %p, align 2
  %w = sext i16 %v to i32
  %s.next = add i32 %s, %w
  %k.next = add nuw i32 %k, 2
  %done = icmp uge i32 %k.next, %n
  br i1 %done, label %exit, label %loop

exit:
  ret i32 %s.next
}
