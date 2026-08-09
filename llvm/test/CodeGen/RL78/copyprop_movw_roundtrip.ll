; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s

; MachineCopyPropagation is registered with UseCopyInstr=true and
; RL78InstrInfo::isCopyInstrImpl reports MOVW_AX_rp / MOVW_rp_AX, so
; "movw <rp>, ax" immediately followed by "movw ax, <rp>" is a provably
; redundant round trip and the second move must be deleted.
;
; Without that wiring MachineCopyPropagation only matches COPY pseudos, which
; ExpandPostRAPseudos has already deleted before the pre-emit passes run, so
; every one of these round trips survived. On the generated function in
; Embench's nsichneu that left 120 dead "movw ax, hl" instructions.
;
; Keep this test. The removal is correct and wanted, but it shrinks code, and
; shrinking that particular function is what exposes an RL78 branch-relaxation
; loop in lld, which gives up after 30 passes with "relaxation not converged".
; If someone reverts the copy propagation to dodge that linker bug, this test
; is what should object.

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16-P3"
target triple = "rl78-unknown-unknown-elf"

@v = external dso_local local_unnamed_addr global [8 x i32], align 2

; Function Attrs: nofree noinline norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none)
define dso_local void @h(i32 noundef %0) local_unnamed_addr addrspace(3) #0 {
  %2 = icmp sgt i32 %0, 0
  br i1 %2, label %3, label %13

3:                                                ; preds = %1
  %4 = load i32, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 7), align 2, !tbaa !3
  %5 = load i32, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 6), align 2, !tbaa !3
  %6 = load i32, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 5), align 2, !tbaa !3
  %7 = load i32, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 4), align 2, !tbaa !3
  %8 = load i32, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 3), align 2, !tbaa !3
  %9 = load i32, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 2), align 2, !tbaa !3
  %10 = load i32, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 1), align 2, !tbaa !3
  %11 = load i32, ptr @v, align 2, !tbaa !3
  br label %14

12:                                               ; preds = %14
  store i32 %24, ptr @v, align 2, !tbaa !3
  store i32 %25, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 1), align 2, !tbaa !3
  store i32 %26, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 2), align 2, !tbaa !3
  store i32 %27, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 3), align 2, !tbaa !3
  store i32 %28, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 4), align 2, !tbaa !3
  store i32 %29, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 5), align 2, !tbaa !3
  store i32 %30, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 6), align 2, !tbaa !3
  store i32 %31, ptr getelementptr inbounds ([8 x i32], ptr @v, i16 0, i16 7), align 2, !tbaa !3
  br label %13

13:                                               ; preds = %12, %1
  ret void

14:                                               ; preds = %3, %14
  %15 = phi i32 [ %32, %14 ], [ 0, %3 ]
  %16 = phi i32 [ %31, %14 ], [ %4, %3 ]
  %17 = phi i32 [ %30, %14 ], [ %5, %3 ]
  %18 = phi i32 [ %29, %14 ], [ %6, %3 ]
  %19 = phi i32 [ %28, %14 ], [ %7, %3 ]
  %20 = phi i32 [ %27, %14 ], [ %8, %3 ]
  %21 = phi i32 [ %26, %14 ], [ %9, %3 ]
  %22 = phi i32 [ %25, %14 ], [ %10, %3 ]
  %23 = phi i32 [ %24, %14 ], [ %11, %3 ]
  %24 = add nsw i32 %22, %23
  %25 = add nsw i32 %21, %22
  %26 = add nsw i32 %20, %21
  %27 = add nsw i32 %19, %20
  %28 = add nsw i32 %18, %19
  %29 = add nsw i32 %17, %18
  %30 = add nsw i32 %16, %17
  %31 = add nsw i32 %16, %24
  %32 = add nuw nsw i32 %15, 1
  %33 = icmp slt i32 %32, %0
  br i1 %33, label %14, label %12
}

attributes #0 = { nofree noinline norecurse nosync nounwind memory(readwrite, argmem: none, inaccessiblemem: none) "no-jump-tables"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+far-code,+mirror-source-0,+relax" }

!llvm.module.flags = !{!0, !1}
!llvm.ident = !{!2}

!0 = !{i32 1, !"wchar_size", i32 2}
!1 = !{i32 1, !"target-abi", !"fc_nd_d32"}
!2 = !{!"LLVM for Renesas RL78 17.0.1.202606 (541cc9327) clang version 17.0.1"}
!3 = !{!4, !4, i64 0}
!4 = !{!"long", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}

; CHECK-LABEL: h:
; No "movw <rp>, ax" may be immediately followed by the reverse copy.
; CHECK-NOT: movw bc, ax{{[[:space:]]+}}movw ax, bc
; CHECK-NOT: movw de, ax{{[[:space:]]+}}movw ax, de
; CHECK-NOT: movw hl, ax{{[[:space:]]+}}movw ax, hl
