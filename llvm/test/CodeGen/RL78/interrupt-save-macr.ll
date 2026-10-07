; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s
; RUN: llc -mtriple=rl78 -mcpu=RL78_S2 -O2 < %s | FileCheck %s --check-prefix=S2
; An S3 interrupt handler that uses MACR (MACH) or calls a function, which may
; use it, saves and restores MACR: the interrupted code may hold a MACH
; accumulator there. S2 has no MACR.

@a = global [8 x i16] zeroinitializer, align 2
@b = global [8 x i16] zeroinitializer, align 2
@out = global i32 0, align 2

; CHECK-LABEL: _isr_mac:
; CHECK:      push ax
; CHECK:      movw ax, !0xffff0
; CHECK-NEXT: push ax
; CHECK-NEXT: movw ax, !0xffff2
; CHECK-NEXT: push ax
; CHECK:      mach
; CHECK:      pop ax
; CHECK-NEXT: movw !0xffff2, ax
; CHECK-NEXT: pop ax
; CHECK-NEXT: movw !0xffff0, ax
; CHECK:      reti
define void @isr_mac() #0 {
entry:
  br label %loop

loop:
  %i = phi i16 [ 0, %entry ], [ %i.next, %loop ]
  %s = phi i32 [ 0, %entry ], [ %s.next, %loop ]
  %pa = getelementptr inbounds i16, ptr @a, i16 %i
  %va = load i16, ptr %pa, align 2
  %xa = sext i16 %va to i32
  %pb = getelementptr inbounds i16, ptr @b, i16 %i
  %vb = load i16, ptr %pb, align 2
  %xb = sext i16 %vb to i32
  %m = mul nsw i32 %xb, %xa
  %s.next = add nsw i32 %m, %s
  %i.next = add nuw nsw i16 %i, 1
  %c = icmp eq i16 %i.next, 8
  br i1 %c, label %exit, label %loop

exit:
  store volatile i32 %s.next, ptr @out, align 2
  ret void
}

; CHECK-LABEL: _isr_call:
; CHECK:      movw ax, !0xffff0
; CHECK-NEXT: push ax
; CHECK-NEXT: movw ax, !0xffff2
; CHECK-NEXT: push ax
; CHECK:      call
; CHECK:      pop ax
; CHECK-NEXT: movw !0xffff2, ax
; CHECK-NEXT: pop ax
; CHECK-NEXT: movw !0xffff0, ax
; CHECK:      reti
; S2-LABEL: _isr_call:
; S2-NOT:   0xffff
; S2:       reti
declare void @ext()

define void @isr_call() #0 {
  call void @ext()
  ret void
}

; CHECK-LABEL: _isr_plain:
; CHECK-NOT:   0xffff
; CHECK:       reti
define void @isr_plain() #0 {
  store volatile i32 1, ptr @out, align 2
  ret void
}

attributes #0 = { "interrupt"="0" "disable-tail-calls"="true" }
