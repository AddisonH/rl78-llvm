; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@dst = external global ptr
declare i8 @step(i8)

; %cur is live across the call so it lands in a non-AX pair, and each use of it
; needs AX. AX is dead at those points, so copying in is enough; exchanging back
; is only needed when AX holds something live.

; CHECK-LABEL: _walk:
; CHECK-NOT:   xchw ax,
; CHECK:       movw ax, bc
define i16 @walk(ptr %p) {
entry:
  br label %loop
loop:
  %cur = phi ptr [ %p, %entry ], [ %next, %loop ]
  %r = call i8 @step(i8 0)
  %next = getelementptr i8, ptr %cur, i16 1
  %c = load i8, ptr %cur, align 1
  %nz = icmp ne i8 %c, 0
  br i1 %nz, label %loop, label %done
done:
  store ptr %cur, ptr @dst, align 2
  ret i16 0
}

; A tied use-def is read as well as written, so it still needs the value in and
; out and keeps the exchange pair.

; CHECK-LABEL: _tied_keeps_exchange:
; CHECK:       xchw ax,
define void @tied_keeps_exchange(ptr %a, ptr %b, i16 %n) {
entry:
  %v = load i16, ptr %a, align 2
  %w = load i16, ptr %b, align 2
  %s = add i16 %v, %w
  %t = mul i16 %s, %n
  store i16 %t, ptr %a, align 2
  store i16 %s, ptr %b, align 2
  ret void
}
