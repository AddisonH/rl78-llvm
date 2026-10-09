; Verifies the if (SrcReg == RL78::MACRH || SrcReg == RL78::MACRL)
; from InstrInfo is not deadcode
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

; CHECK: machu
; CHECK: machu
; CHECK-NEXT: movw ax, !0xffff0
; CHECK: mulhu
; CHECK: mulhu
; CHECK: mulhu
; CHECK: xchw ax, bc
; CHECK-NEXT:movw ax, !0xffff2
; CHECK-NEXT:xchw ax, bc


target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

%struct._reent = type { i16, ptr, ptr, ptr, i16, [25 x i8], i16, ptr, i16, ptr, ptr, i16, ptr, ptr, i16, ptr, %union.anon, ptr, %struct._atexit, ptr, %struct._glue, [3 x %struct.__sFILE] }
%union.anon = type { %struct.anon }
%struct.anon = type { i16, ptr, [26 x i8], %struct.__tm, i16, i64, %struct._rand48, %struct._mbstate_t, %struct._mbstate_t, %struct._mbstate_t, [8 x i8], [24 x i8], i16, %struct._mbstate_t, %struct._mbstate_t, %struct._mbstate_t, %struct._mbstate_t, %struct._mbstate_t, i16 }
%struct.__tm = type { i16, i16, i16, i16, i16, i16, i16, i16, i16 }
%struct._rand48 = type { [3 x i16], [3 x i16], i16 }
%struct._mbstate_t = type { i16, %union.anon.0 }
%union.anon.0 = type { i16, [2 x i8] }
%struct._atexit = type { ptr, i16, [32 x ptr], %struct._on_exit_args }
%struct._on_exit_args = type { [32 x ptr], [32 x ptr], i32, i32 }
%struct._glue = type { ptr, i16, ptr }
%struct.__sFILE = type { ptr, i16, i16, i16, i16, %struct.__sbuf, i16, ptr, ptr, ptr, ptr, ptr, %struct.__sbuf, ptr, i16, [3 x i8], [1 x i8], %struct.__sbuf, i16, i32, ptr, i16, %struct._mbstate_t, i16 }
%struct.__sbuf = type { ptr, i16 }

define dso_local void @__dorand48(ptr nocapture noundef readonly %r, ptr nocapture noundef %xseed)  {
entry:
  %_mult = getelementptr inbounds %struct._reent, ptr %r, i16 0, i32 16, i32 0, i32 6, i32 1
  %0 = load i16, ptr %_mult, align 2, !tbaa !3
  %conv = zext i16 %0 to i32
  %1 = load i16, ptr %xseed, align 2, !tbaa !6
  %conv2 = zext i16 %1 to i32
  %mul = mul nuw i32 %conv2, %conv
  %_add = getelementptr inbounds %struct._reent, ptr %r, i16 0, i32 16, i32 0, i32 6, i32 2
  %2 = load i16, ptr %_add, align 2, !tbaa !3
  %conv5 = zext i16 %2 to i32
  %add = add nuw i32 %mul, %conv5
  %conv6 = trunc i32 %add to i16
  %shr = lshr i32 %add, 16
  %arrayidx13 = getelementptr inbounds i16, ptr %xseed, i16 1
  %3 = load i16, ptr %arrayidx13, align 2, !tbaa !6
  %conv14 = zext i16 %3 to i32
  %mul15 = mul nuw i32 %conv14, %conv
  %arrayidx19 = getelementptr inbounds %struct._reent, ptr %r, i16 0, i32 16, i32 0, i32 6, i32 1, i16 1
  %4 = load i16, ptr %arrayidx19, align 2, !tbaa !3
  %conv20 = zext i16 %4 to i32
  %mul23 = mul nuw i32 %conv20, %conv2
  %add24 = add nuw i32 %shr, %mul15
  %add25 = add i32 %add24, %mul23
  %conv26 = trunc i32 %add25 to i16
  %shr28 = lshr i32 %add25, 16
  %arrayidx33 = getelementptr inbounds i16, ptr %xseed, i16 2
  %5 = load i16, ptr %arrayidx33, align 2, !tbaa !6
  %mul34 = mul i16 %5, %0
  %mul40 = mul i16 %4, %3
  %add41 = add i16 %mul34, %mul40
  %arrayidx45 = getelementptr inbounds %struct._reent, ptr %r, i16 0, i32 16, i32 0, i32 6, i32 1, i16 2
  %6 = load i16, ptr %arrayidx45, align 2, !tbaa !3
  %mul47 = mul i16 %6, %1
  %add48 = add i16 %add41, %mul47
  store i16 %conv6, ptr %xseed, align 2, !tbaa !6
  store i16 %conv26, ptr %arrayidx13, align 2, !tbaa !6
  %7 = trunc i32 %shr28 to i16
  %conv55 = add i16 %add48, %7
  store i16 %conv55, ptr %arrayidx33, align 2, !tbaa !6
  ret void
}


!3 = !{!4, !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !7, i64 0}
!7 = !{!"short", !4, i64 0}
