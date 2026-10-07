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
