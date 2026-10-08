; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s
; RUN: llc -mtriple=rl78 -O2 -rl78-pin-address-regs=true < %s \
; RUN:   | FileCheck %s --check-prefix=PINNED

; A list walk: the node pointer is loaded (p = p->next), carried around the
; loop, and is the base of both loads. Such loaded pointers are left to the
; register allocator (BC, DE or HL), so the pointer is not copied into a fixed
; pair (push/pop) each time round, as it was when every base was pinned to
; HL/DE before allocation. (Other bases keep the pin: unpinned, the allocator
; spilled worse around arithmetic pointers, Embench huffbench +18%.)

; CHECK-LABEL: _find:
; CHECK:       [[LOOP:\.LBB0_[0-9]+]]:
; CHECK-NOT:   push
; CHECK-NOT:   pop
; CHECK:       b{{.*}}[[LOOP]]

; PINNED-LABEL: _find:
; PINNED:       push

%node = type { ptr, i16 }

define ptr @find(ptr %n, i16 %key) {
entry:
  %e = icmp eq ptr %n, null
  br i1 %e, label %done, label %loop

loop:
  %p = phi ptr [ %n, %entry ], [ %next, %cont ]
  %kp = getelementptr inbounds i8, ptr %p, i16 2
  %k = load i16, ptr %kp, align 2
  %hit = icmp eq i16 %k, %key
  br i1 %hit, label %done, label %cont

cont:
  %next = load ptr, ptr %p, align 2
  %end = icmp eq ptr %next, null
  br i1 %end, label %done, label %loop

done:
  %r = phi ptr [ null, %entry ], [ %p, %loop ], [ null, %cont ]
  ret ptr %r
}
