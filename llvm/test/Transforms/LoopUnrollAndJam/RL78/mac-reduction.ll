; RL78 has one MACR. Unroll-and-jam of a nest whose inner loop is a MACH
; reduction would give every jammed copy its own accumulator, each swapped
; through MACR around every MACH, so RL78's TTI keeps such nests unjammed.
; Other nests are still jammed.
; RUN: opt -passes=loop-unroll-and-jam -unroll-and-jam-count=2 -S < %s | FileCheck %s

; CHECK-LABEL: @mac(
; CHECK: mul nsw i32
; CHECK-NOT: mul nsw i32
; CHECK-LABEL: @add(
; CHECK: %.lcssa.1 = phi i32

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: readwrite)
define void @mac(i16 noundef %0, ptr noalias nofree noundef writeonly captures(none) %1, ptr noalias nofree noundef readonly captures(none) %2, ptr noalias nofree noundef readonly captures(none) %3) #0 {
  %5 = icmp eq i16 %0, 0
  br i1 %5, label %9, label %6

6:                                                ; preds = %4, %10
  %7 = phi i16 [ %12, %10 ], [ 0, %4 ]
  %8 = getelementptr [2 x i8], ptr %3, i16 %7
  br label %14

9:                                                ; preds = %10, %4
  ret void

10:                                               ; preds = %14
  %11 = getelementptr inbounds nuw [4 x i8], ptr %1, i16 %7
  store i32 %25, ptr %11, align 2
  %12 = add nuw i16 %7, 1
  %13 = icmp eq i16 %12, %0
  br i1 %13, label %9, label %6

14:                                               ; preds = %6, %14
  %15 = phi i16 [ 0, %6 ], [ %26, %14 ]
  %16 = phi i32 [ 0, %6 ], [ %25, %14 ]
  %17 = getelementptr inbounds nuw [2 x i8], ptr %2, i16 %15
  %18 = load i16, ptr %17, align 2
  %19 = sext i16 %18 to i32
  %20 = mul i16 %15, %0
  %21 = getelementptr [2 x i8], ptr %8, i16 %20
  %22 = load i16, ptr %21, align 2
  %23 = sext i16 %22 to i32
  %24 = mul nsw i32 %23, %19
  %25 = add nsw i32 %24, %16
  %26 = add nuw i16 %15, 1
  %27 = icmp eq i16 %26, %0
  br i1 %27, label %10, label %14
}

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: readwrite)
define void @add(i16 noundef %0, ptr noalias nofree noundef writeonly captures(none) %1, ptr noalias nofree noundef readonly captures(none) %2, ptr noalias nofree noundef readonly captures(none) %3) #0 {
  %5 = icmp eq i16 %0, 0
  br i1 %5, label %9, label %6

6:                                                ; preds = %4, %10
  %7 = phi i16 [ %12, %10 ], [ 0, %4 ]
  %8 = getelementptr [4 x i8], ptr %3, i16 %7
  br label %14

9:                                                ; preds = %10, %4
  ret void

10:                                               ; preds = %14
  %11 = getelementptr inbounds nuw [4 x i8], ptr %1, i16 %7
  store i32 %23, ptr %11, align 2
  %12 = add nuw i16 %7, 1
  %13 = icmp eq i16 %12, %0
  br i1 %13, label %9, label %6

14:                                               ; preds = %6, %14
  %15 = phi i16 [ 0, %6 ], [ %24, %14 ]
  %16 = phi i32 [ 0, %6 ], [ %23, %14 ]
  %17 = getelementptr inbounds nuw [4 x i8], ptr %2, i16 %15
  %18 = load i32, ptr %17, align 2
  %19 = mul i16 %15, %0
  %20 = getelementptr [4 x i8], ptr %8, i16 %19
  %21 = load i32, ptr %20, align 2
  %22 = add i32 %18, %16
  %23 = add i32 %22, %21
  %24 = add nuw i16 %15, 1
  %25 = icmp eq i16 %24, %0
  br i1 %25, label %10, label %14
}

attributes #0 = { nofree norecurse nosync nounwind memory(argmem: readwrite) "target-cpu"="RL78_S3" }
