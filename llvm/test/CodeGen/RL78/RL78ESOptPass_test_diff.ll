; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_diff
; CHECK:	movw ax, #13
; CHECK-NEXT:	movw es:[hl+4], ax
; CHECK-NEXT:	movw ax, #12
; CHECK-NEXT:	movw es:[hl], ax

@p = dso_local local_unnamed_addr global ptr addrspace(2) null, align 2

define dso_local void @test_diff() local_unnamed_addr {

  %1 = load ptr addrspace(2), ptr @p, align 2
  store i16 12, ptr addrspace(2) %1, align 2
  %arrayidx1 = getelementptr inbounds i16, ptr addrspace(2) %1, i16 2
  store i16 13, ptr addrspace(2) %arrayidx1, align 2
  ret void
}
