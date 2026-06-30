; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_reg_a
; CHECK: mov es, a
; CHECK-NOT: mov es, a
define dso_local void @test_reg_a(ptr addrspace(2) nocapture noundef writeonly %x) local_unnamed_addr{
  %arrayidx = getelementptr inbounds i16, ptr addrspace(2) %x, i16 2
  store i16 12, ptr addrspace(2) %arrayidx, align 2
  %arrayidx1 = getelementptr inbounds i16, ptr addrspace(2) %x, i16 3
  store i16 13, ptr addrspace(2) %arrayidx1, align 2
  %arrayidx2 = getelementptr inbounds i16, ptr addrspace(2) %x, i16 6
  store i16 13, ptr addrspace(2) %arrayidx2, align 2
  %arrayidx3 = getelementptr inbounds i16, ptr addrspace(2) %x, i16 10
  store i16 13, ptr addrspace(2) %arrayidx3, align 2
  %arrayidx4 = getelementptr inbounds i16, ptr addrspace(2) %x, i16 24
  store i16 13, ptr addrspace(2) %arrayidx4, align 2
  ret void
}

; Tests elimination of redundant ES initializations even with mixed constant and variable indices.
; CHECK-LABEL: _test_reg_b
; CHECK: mov es, a
; CHECK-NOT: mov es, a
define dso_local void @test_reg_b(ptr addrspace(2) nocapture noundef writeonly %x, i16 noundef %i) local_unnamed_addr #0 {
  %arrayidx = getelementptr inbounds i16, ptr addrspace(2) %x, i16 2
  store i16 12, ptr addrspace(2) %arrayidx, align 2
  %add = add nsw i16 %i, 3
  %arrayidx1 = getelementptr inbounds i16, ptr addrspace(2) %x, i16 %add
  store i16 13, ptr addrspace(2) %arrayidx1, align 2
  %arrayidx2 = getelementptr inbounds i16, ptr addrspace(2) %x, i16 5
  store i16 12, ptr addrspace(2) %arrayidx2, align 2
  %add3 = add nsw i16 %i, 4
  %arrayidx4 = getelementptr inbounds i16, ptr addrspace(2) %x, i16 %add3
  store i16 13, ptr addrspace(2) %arrayidx4, align 2
  ret void
}
