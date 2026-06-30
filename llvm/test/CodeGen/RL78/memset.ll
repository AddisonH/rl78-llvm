; RUN: llc -march=rl78 < %s | FileCheck %s
; RUN: llc -march=rl78 < %s -mattr=+far-data | FileCheck %s --check-prefix=FAR

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; INLINE-LABEL: _test_inline_memset:
; INLINE-NOT: call
; INLINE: ret
; FAR-LABEL: _test_inline_memset:
; FAR-NOT: call
; FAR: ret
define dso_local void @test_inline_memset(ptr %dst) {
entry:
  tail call void @llvm.memset.p0.i16(ptr %dst, i8 0, i16 3, i1 false)
  ret void
}

declare void @llvm.memset.p0.i16(ptr, i8, i16, i1 immarg)

; CHECK-LABEL: _test_libcall_memset:
; CHECK: call !_memset
; CHECK: ret
; FAR-LABEL: _test_libcall_memset:
; FAR: !!__COM_memset_f
; FAR: ret
define dso_local void @test_libcall_memset(ptr %dst, i16 %n) {
entry:
  tail call void @llvm.memset.p0.i16(ptr %dst, i8 0, i16 %n, i1 false)
  ret void
}

; CHECK-LABEL: _test_far_memset:
; CHECK: call !__COM_memset_f
; CHECK: ret
; FAR-LABEL: _test_far_memset:
; FAR: call !!__COM_memset_f
; FAR: ret
define dso_local void @test_far_memset(ptr addrspace(2) %dst, i16 noundef %n) {
entry:
  tail call void @llvm.memset.p2.i16(ptr addrspace(2) %dst, i8 0, i16 %n, i1 false)
  ret void
}

declare void @llvm.memset.p2.i16(ptr addrspace(2), i8, i16, i1 immarg)
