; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@global_array = external dso_local local_unnamed_addr global [0 x i16], align 2
@global_var = external dso_local global i16, align 2

; CHECK-LABEL: _test_SelectADDRri
; CHECK: movw hl, ax
; CHECK-NEXT: movw ax, [hl]
define dso_local i16 @test_SelectADDRri_true(ptr nocapture noundef readonly %0) local_unnamed_addr  {
  %2 = load i16, ptr %0, align 2
  ret i16 %2
}

; Tests SelectADDRri with ADD base + constant offset.
; CHECK-LABEL: _test_add_offset
; CHECK:	movw hl, ax
; CHECK-NEXT:	movw ax, [hl+6]
define dso_local i16 @test_add_offset(ptr nocapture noundef readonly %0) local_unnamed_addr  {
  %2 = getelementptr inbounds i16, ptr %0, i16 3
  %3 = load i16, ptr %2, align 2
  ret i16 %3
}

; Tests SelectADDRri with ADD base + LOW16(symbol).
; CHECK-LABEL: _test_low16_add2
; CHECK:	movw bc, ax
; CHECK-NEXT:	movw ax, LOWW(_global_var)[bc]
define dso_local i16 @test_low16_add2(ptr nocapture noundef readonly %0) local_unnamed_addr  {
  %2 = getelementptr inbounds i8, ptr %0, i16 ptrtoint (ptr @global_var to i16)
  %3 = load i16, ptr %2, align 2
  ret i16 %3
}
