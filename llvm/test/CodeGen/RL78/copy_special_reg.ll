; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_cs_r:
; CHECK:       xch a, x
; CHECK-NEXT:  mov cs, a
define dso_local void @test_cs_r(ptr addrspace(3) noundef %fp) {
  call addrspace(3) void %fp()
  ret void
}

; CHECK-LABEL: _test_es_r:
; CHECK: mov a, x
; CHECK-NEXT: mov es, a
define dso_local i8 @test_es_r(ptr addrspace(2) nocapture noundef readonly %0) local_unnamed_addr {
  %2 = load i8, ptr addrspace(2) %0, align 1
  ret i8 %2
}

; CHECK-LABEL: _test_rp_sp:
; CHECK: ; %bb.0:
; CHECK-NEXT:	movw ax, sp
define dso_local i16 @test_rp_sp() {
  %sp = call ptr @llvm.stacksave()
  %sp_i16 = ptrtoint ptr %sp to i16
  ret i16 %sp_i16
}


declare ptr @llvm.stacksave()
