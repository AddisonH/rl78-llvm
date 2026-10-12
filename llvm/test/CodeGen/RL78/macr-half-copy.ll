; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s

; The high half of one MACH result is the low half of the next addend: a copy
; from MACRH to MACRL. Both are memory, so the value goes through AX, saved
; around it. (This copy used to be emitted as "xchw ax, macrl" and stopped the
; compiler; newlib's rand48 has it.)

; CHECK-LABEL: _step:
; CHECK:      push ax{{[[:space:]]+}}movw ax, !0xffff2{{[[:space:]]+}}movw !0xffff0, ax{{[[:space:]]+}}pop ax
; CHECK:      machu

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite)
define dso_local void @step(ptr nofree noundef captures(none) %x, ptr nofree noundef readonly captures(none) %a, i16 noundef %c) local_unnamed_addr #0 {
entry:
  %0 = load i16, ptr %a, align 2, !tbaa !8
  %conv = zext i16 %0 to i32
  %1 = load i16, ptr %x, align 2, !tbaa !8
  %conv2 = zext i16 %1 to i32
  %mul = mul nuw i32 %conv2, %conv
  %conv3 = zext i16 %c to i32
  %add = add nuw i32 %mul, %conv3
  %conv4 = trunc i32 %add to i16
  %shr = lshr i32 %add, 16
  %arrayidx7 = getelementptr inbounds nuw i8, ptr %x, i16 2
  %2 = load i16, ptr %arrayidx7, align 2, !tbaa !8
  %conv8 = zext i16 %2 to i32
  %mul9 = mul nuw i32 %conv8, %conv
  %add10 = add nuw i32 %shr, %mul9
  %arrayidx11 = getelementptr inbounds nuw i8, ptr %a, i16 2
  %3 = load i16, ptr %arrayidx11, align 2, !tbaa !8
  %conv12 = zext i16 %3 to i32
  %mul15 = mul nuw i32 %conv12, %conv2
  %add16 = add i32 %add10, %mul15
  %conv17 = trunc i32 %add16 to i16
  %shr18 = lshr i32 %add16, 16
  %arrayidx21 = getelementptr inbounds nuw i8, ptr %x, i16 4
  %4 = load i16, ptr %arrayidx21, align 2, !tbaa !8
  %conv22 = zext i16 %4 to i32
  %mul23 = mul nuw i32 %conv22, %conv
  %mul28 = mul nuw i32 %conv12, %conv8
  %add29 = add i32 %mul23, %mul28
  %arrayidx30 = getelementptr inbounds nuw i8, ptr %a, i16 4
  %5 = load i16, ptr %arrayidx30, align 2, !tbaa !8
  %conv31 = zext i16 %5 to i32
  %mul34 = mul nuw i32 %conv31, %conv2
  %add35 = add i32 %add29, %mul34
  %add36 = add i32 %add35, %shr18
  store i16 %conv4, ptr %x, align 2, !tbaa !8
  store i16 %conv17, ptr %arrayidx7, align 2, !tbaa !8
  %conv39 = trunc i32 %add36 to i16
  store i16 %conv39, ptr %arrayidx21, align 2, !tbaa !8
  ret void
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0,+relax" }

!llvm.module.flags = !{!0, !1}
!llvm.errno.tbaa = !{!3}

!0 = !{i32 1, !"wchar_size", i32 2}
!1 = !{i32 1, !"target-abi", !"nc_nd_d32"}
!3 = !{!4, !5, i64 0}
!4 = !{!"__libc_errno", !5, i64 0}
!5 = !{!"int", !6, i64 0}
!6 = !{!"omnipotent char", !7, i64 0}
!7 = !{!"Simple C/C++ TBAA"}
!8 = !{!9, !9, i64 0}
!9 = !{!"short", !6, i64 0}
