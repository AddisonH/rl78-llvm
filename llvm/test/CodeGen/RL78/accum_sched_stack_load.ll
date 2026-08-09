; Accumulator-aware reordering of stack-slot loads.
;
; A stack-slot load into a non-AX pair must stage through AX. When AX is live
; the exchange pass pays two instructions to preserve it:
;
;   movw ax, [sp+M] / xchw ax, bc / movw ax, [sp+N] / xchw ax, bc
;
; Loading the BC-destined value first needs only three, because AX is free:
;
;   movw ax, [sp+N] / movw bc, ax / movw ax, [sp+M]
;
; RUN: llc -O2 -mtriple=rl78 -rl78-accum-sched=false < %s \
; RUN:   | FileCheck %s --check-prefix=NOSCHED
; RUN: llc -O2 -mtriple=rl78 -rl78-accum-sched=true < %s \
; RUN:   | FileCheck %s --check-prefix=SCHED

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Without the reordering every conflicting reload costs an exchange pair.
; NOSCHED-COUNT-40: xchw
; NOSCHED-NOT: xchw

; With it, eight of those pairs collapse to a copy out of AX.
; SCHED-COUNT-32: xchw
; SCHED-NOT: xchw

define dso_local i32 @g(i32 noundef %0, i32 noundef %1, i16 noundef %2) local_unnamed_addr {
  %4 = shl i32 %1, 3
  %5 = xor i32 %4, %0
  %6 = lshr i32 %0, 2
  %7 = add i32 %6, %1
  %8 = mul i32 %0, 3
  %9 = add i32 %8, %1
  %10 = xor i32 %5, %7
  %11 = zext i16 %2 to i32
  %12 = add i32 %10, %11
  %13 = sub i32 %7, %9
  %14 = lshr i32 %5, 5
  %15 = xor i32 %14, %9
  %16 = add i32 %12, %13
  %17 = xor i32 %15, %13
  %18 = shl i32 %17, 1
  %19 = add i32 %15, %12
  %20 = lshr i32 %19, 1
  %21 = add i32 %5, %7
  %22 = add i32 %21, %9
  %23 = xor i32 %16, %22
  %24 = xor i32 %23, %18
  %25 = xor i32 %24, %20
  ret i32 %25
}
