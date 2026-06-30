; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_SelectADDRr
; CHECK: mov a, c
; CHECK-NEXT: mov1 cy, a.2
; CHECK-NEXT: and1 cy, [hl].1
; CHECK-NEXT: mov1 [hl].1, cy

define dso_local void @test_SelectADDRr(ptr noundef %0, i8 noundef %1, i8 noundef %2) local_unnamed_addr  {
  tail call void @llvm.rl78.and1.p0(ptr %0, i8 1, i8 %1, i8 2)
  ret void
}

declare void @llvm.rl78.and1.p0(ptr, i8, i8, i8) 
