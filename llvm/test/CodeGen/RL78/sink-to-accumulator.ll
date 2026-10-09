; RL78SinkToAccumulator: MACH_cg reads AX and BC. Its BC operand is loaded through
; AX, so loading the AX operand first parks it in a stack slot. Sunk to the
; MACH_cg, the AX operand is loaded straight into AX after BC is set up.
; RUN: llc -O2 < %s | FileCheck %s
; RUN: llc -O2 -rl78-sink-to-acc=false < %s | FileCheck %s --check-prefix=NOSINK

; CHECK-LABEL: _dot4:
; CHECK:       movw ax, [hl+2]
; CHECK-NEXT:  movw bc, ax
; CHECK:       movw ax, [de]
; CHECK-NEXT:  mach
; CHECK:       movw ax, [hl+4]
; CHECK-NEXT:  movw bc, ax
; CHECK-NEXT:  movw ax, [de]
; CHECK-NEXT:  mach
; CHECK-NOT:   movw [sp+6], ax
; CHECK:       ret

; NOSINK-LABEL: _dot4:
; NOSINK:       mulh
; NOSINK:       movw ax, [de]
; NOSINK-NEXT:  movw [sp+6], ax
; NOSINK:       movw ax, [sp+6]
; NOSINK-NEXT:  mach

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define i32 @dot4(ptr nofree noundef readonly captures(none) %0, ptr nofree noundef readonly captures(none) %1, i16 noundef %2) #0 {
  %4 = load i16, ptr %0, align 2
  %5 = sext i16 %4 to i32
  %6 = load i16, ptr %1, align 2
  %7 = sext i16 %6 to i32
  %8 = mul nsw i32 %7, %5
  %9 = getelementptr inbounds nuw [2 x i8], ptr %1, i16 %2
  %10 = getelementptr inbounds nuw i8, ptr %0, i16 2
  %11 = load i16, ptr %10, align 2
  %12 = sext i16 %11 to i32
  %13 = load i16, ptr %9, align 2
  %14 = sext i16 %13 to i32
  %15 = mul nsw i32 %14, %12
  %16 = add nsw i32 %15, %8
  %17 = getelementptr inbounds nuw [2 x i8], ptr %9, i16 %2
  %18 = getelementptr inbounds nuw i8, ptr %0, i16 4
  %19 = load i16, ptr %18, align 2
  %20 = sext i16 %19 to i32
  %21 = load i16, ptr %17, align 2
  %22 = sext i16 %21 to i32
  %23 = mul nsw i32 %22, %20
  %24 = add nsw i32 %16, %23
  %25 = getelementptr inbounds nuw [2 x i8], ptr %17, i16 %2
  %26 = getelementptr inbounds nuw i8, ptr %0, i16 6
  %27 = load i16, ptr %26, align 2
  %28 = sext i16 %27 to i32
  %29 = load i16, ptr %25, align 2
  %30 = sext i16 %29 to i32
  %31 = mul nsw i32 %30, %28
  %32 = add nsw i32 %24, %31
  ret i32 %32
}

attributes #0 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(argmem: read) "target-cpu"="RL78_S3" }
