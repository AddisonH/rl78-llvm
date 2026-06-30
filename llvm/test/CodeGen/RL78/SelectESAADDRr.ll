; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_SelectESADDRr
; CHECK: mov a, x
; CHECK-NEXT: mov es, a
; CHECK-NEXT: push de
; CHECK-NEXT: pop hl
; CHECK-NEXT: set1 es:[hl].0

define dso_local void @test_SelectESADDRr(ptr addrspace(2) nocapture noundef %0) local_unnamed_addr {
  %2 = load i8, ptr addrspace(2) %0, align 1
  %3 = or i8 %2, 1
  store i8 %3, ptr addrspace(2) %0, align 1
  ret void
}
