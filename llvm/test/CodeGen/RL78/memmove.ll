; RUN: llc < %s -mtriple=rl78 | FileCheck %s


target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"


; CHECK-LABEL: _test_inline_memmove:
; CHECK-NOT: call
; CHECK: ret
; FAR-LABEL: _test_inline_memmove:
; FAR-NOT: call
; FAR: ret
define dso_local void @test_inline_memmove(ptr nocapture %a, ptr nocapture %b) {
entry:
  tail call void @llvm.memmove.p0.p0.i16(
    ptr noundef nonnull align 1 dereferenceable(3) %a,
    ptr noundef nonnull align 1 dereferenceable(3) %b,
    i16 3, i1 false)
  ret void
}

declare void @llvm.memmove.p0.p0.i16(ptr nocapture writeonly, ptr nocapture readonly, i16, i1 immarg)

; CHECK-LABEL: _test_libcall_memmove:
; CHECK: call !_memmove
; CHECK: ret
; FAR-LABEL: _test_libcall_memmove:
; FAR: call !!__COM_memmove_ff
; FAR: ret
define dso_local void @test_libcall_memmove(ptr nocapture %a, ptr nocapture %b, i16 noundef %n) {
entry:
  tail call void @llvm.memmove.p0.p0.i16(ptr align 1 %a, ptr align 1 %b, i16 %n, i1 false)
  ret void
}

; CHECK-LABEL: _test_mixed_AS:
; CHECK: call !__COM_memmove_ff
; CHECK: ret
; FAR-LABEL: _test_mixed_AS:
; FAR: call !!__COM_memmove_ff
; FAR: ret
define dso_local void @test_mixed_AS(i16 noundef %n) {
entry:
  %call = tail call ptr addrspace(2) @far_ptr() #4
  %call1 = tail call ptr @near_ptr() #4
  tail call void @llvm.memmove.p0.p2.i16(ptr align 1 %call1, ptr addrspace(2) align 1 %call, i16 %n, i1 false)
  ret void
}

declare dso_local ptr addrspace(2) @far_ptr(...)
declare dso_local ptr @near_ptr(...)

declare void @llvm.memmove.p0.p2.i16(ptr nocapture writeonly, ptr addrspace(2) nocapture readonly, i16, i1 immarg)
