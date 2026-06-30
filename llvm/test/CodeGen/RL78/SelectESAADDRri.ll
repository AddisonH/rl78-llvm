; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_SelectESADDRri
; CHECK: shrw ax, 8
; CHECK-NEXT: mov a, x
; CHECK-NEXT: mov es, a
; CHECK-NEXT: push de
; CHECK-NEXT: pop hl
; CHECK-NEXT: movw ax, es:[hl]

define dso_local i16 @test_SelectESADDRri(ptr addrspace(2) nocapture noundef readonly %0) local_unnamed_addr {
  %2 = load i16, ptr addrspace(2) %0, align 2
  ret i16 %2
}

; CHECK-LABEL: _test_SelectESADDRri_offset
; CHECK: shrw ax, 8
; CHECK-NEXT: mov a, x
; CHECK-NEXT: mov es, a
; CHECK-NEXT: push de
; CHECK-NEXT: pop hl
; CHECK: movw ax, es:[hl+4]

define dso_local i16 @test_SelectESADDRri_offset(ptr addrspace(2) nocapture noundef readonly %0) local_unnamed_addr {
  %ptr_i16 = getelementptr i16, ptr addrspace(2) %0, i16 2
  %val = load i16, ptr addrspace(2) %ptr_i16, align 2
  ret i16 %val
}
