; RUN: llc -verify-machineinstrs -mtriple=rl78 -O2 < %s | FileCheck %s

; RL78 memory operands take one register plus an unsigned byte displacement.
; LSR must not advance the pointer first and address the unrolled accesses
; at negative offsets (each then needs an ADDW): base + 0, 2, 4, 6.

; CHECK-LABEL: _sum4:
; CHECK:       [[LOOP:\.LBB[0-9_]+]]:
; CHECK-NOT:   addw ax, #-
; CHECK-NOT:   addw ax, #655
; CHECK:       {{\[(hl|de)\+6\]|6\[bc\]}}
; CHECK:       b{{.*}}[[LOOP]]
define i16 @sum4(ptr %p, i16 %n) {
entry:
  br label %loop

loop:
  %i = phi i16 [ 0, %entry ], [ %i.next, %loop ]
  %s = phi i16 [ 0, %entry ], [ %s3, %loop ]
  %a0 = getelementptr inbounds i16, ptr %p, i16 %i
  %v0 = load i16, ptr %a0, align 2
  %i1 = or disjoint i16 %i, 1
  %a1 = getelementptr inbounds i16, ptr %p, i16 %i1
  %v1 = load i16, ptr %a1, align 2
  %i2 = or disjoint i16 %i, 2
  %a2 = getelementptr inbounds i16, ptr %p, i16 %i2
  %v2 = load i16, ptr %a2, align 2
  %i3 = or disjoint i16 %i, 3
  %a3 = getelementptr inbounds i16, ptr %p, i16 %i3
  %v3 = load i16, ptr %a3, align 2
  %s0 = xor i16 %s, %v0
  %s1 = xor i16 %s0, %v1
  %s2 = xor i16 %s1, %v2
  %s3 = xor i16 %s2, %v3
  %i.next = add nuw i16 %i, 4
  %done = icmp uge i16 %i.next, %n
  br i1 %done, label %exit, label %loop

exit:
  ret i16 %s3
}
