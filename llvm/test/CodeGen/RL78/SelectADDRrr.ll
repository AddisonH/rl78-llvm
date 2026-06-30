; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_SelectADDRrr
; CHECK: movw hl, ax
; CHECK-NEXT: mov a, [hl+b]
define dso_local i8 @test_SelectADDRrr(ptr nocapture noundef readonly %0, i8 noundef %1) local_unnamed_addr {
  %3 = zext i8 %1 to i16
  %4 = getelementptr inbounds i8, ptr %0, i16 %3
  %5 = load i8, ptr %4, align 1
  ret i8 %5
}
