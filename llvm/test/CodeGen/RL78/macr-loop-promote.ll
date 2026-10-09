; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s
; The accumulator of a MACH_cg loop stays in MACR: written once before the loop,
; read once after it, no MACR traffic inside the loop.

; CHECK-LABEL: _dot:
; CHECK: movw !0xffff0, ax
; CHECK: movw !0xffff2, ax
; CHECK: .LBB0_[[L:[0-9]+]]:
; CHECK-NOT: 0xffff
; CHECK: mach
; CHECK-NOT: 0xffff
; CHECK: bnz $.LBB0_[[L]]
; CHECK: movw ax, !0xffff
; CHECK: ret
define i32 @dot(ptr %a, ptr %b, i16 %n) {
entry:
  %z = icmp eq i16 %n, 0
  br i1 %z, label %exit, label %loop

loop:
  %i = phi i16 [ %i.next, %loop ], [ 0, %entry ]
  %s = phi i32 [ %s.next, %loop ], [ 0, %entry ]
  %pa = getelementptr inbounds i16, ptr %a, i16 %i
  %va = load i16, ptr %pa, align 2
  %xa = sext i16 %va to i32
  %pb = getelementptr inbounds i16, ptr %b, i16 %i
  %vb = load i16, ptr %pb, align 2
  %xb = sext i16 %vb to i32
  %m = mul nsw i32 %xb, %xa
  %s.next = add nsw i32 %m, %s
  %i.next = add nuw i16 %i, 1
  %c = icmp eq i16 %i.next, %n
  br i1 %c, label %exit, label %loop

exit:
  %r = phi i32 [ 0, %entry ], [ %s.next, %loop ]
  ret i32 %r
}

; A call may clobber MACR: the accumulator is copied in and out around every
; MACH_cg.
; CHECK-LABEL: _dot_call:
; CHECK: .LBB1_[[L:[0-9]+]]:
; CHECK: movw !0xffff0, ax
; CHECK: mach
; CHECK: movw ax, !0xffff
; CHECK: call
; CHECK: bnz $.LBB1_[[L]]
declare void @ext()

define i32 @dot_call(ptr %a, ptr %b, i16 %n) {
entry:
  %z = icmp eq i16 %n, 0
  br i1 %z, label %exit, label %loop

loop:
  %i = phi i16 [ %i.next, %loop ], [ 0, %entry ]
  %s = phi i32 [ %s.next, %loop ], [ 0, %entry ]
  %pa = getelementptr inbounds i16, ptr %a, i16 %i
  %va = load i16, ptr %pa, align 2
  %xa = sext i16 %va to i32
  %pb = getelementptr inbounds i16, ptr %b, i16 %i
  %vb = load i16, ptr %pb, align 2
  %xb = sext i16 %vb to i32
  %m = mul nsw i32 %xb, %xa
  %s.next = add nsw i32 %m, %s
  call void @ext()
  %i.next = add nuw i16 %i, 1
  %c = icmp eq i16 %i.next, %n
  br i1 %c, label %exit, label %loop

exit:
  %r = phi i32 [ 0, %entry ], [ %s.next, %loop ]
  ret i32 %r
}
