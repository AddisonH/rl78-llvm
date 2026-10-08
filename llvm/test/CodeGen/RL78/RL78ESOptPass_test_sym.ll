; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@y = dso_local local_unnamed_addr global ptr addrspace(2) null, align 2

; Tests elimination of redundant MOV_es_imm instructions.
; CHECK-LABEL: _test_sym
; CHECK: mov es, a
; CHECK-NOT: mov es, a
define dso_local void @test_sym() local_unnamed_addr {
entry:
  %0 = load ptr addrspace(2), ptr @y, align 2
  %arrayidx = getelementptr inbounds i16, ptr addrspace(2) %0, i16 2
  store i16 12, ptr addrspace(2) %arrayidx, align 2
  %arrayidx1 = getelementptr inbounds i16, ptr addrspace(2) %0, i16 3
  store i16 13, ptr addrspace(2) %arrayidx1, align 2
  %arrayidx2 = getelementptr inbounds i16, ptr addrspace(2) %0, i16 6
  store i16 13, ptr addrspace(2) %arrayidx2, align 2
  %arrayidx3 = getelementptr inbounds i16, ptr addrspace(2) %0, i16 10
  store i16 13, ptr addrspace(2) %arrayidx3, align 2
  %arrayidx4 = getelementptr inbounds i16, ptr addrspace(2) %0, i16 24
  store i16 13, ptr addrspace(2) %arrayidx4, align 2
  ret void
}

; Tests elimination of redundant MOV_es_A without a preceding copy in R1.
; The far pointer is reloaded after a byte store through it, which may alias
; the pointer itself; the loads are marked invariant so that both stores use
; the same ES value (without that, both MOV_es_A are required).
; CHECK-LABEL: _test_copy
; CHECK: mov es, a
; CHECK-NOT: mov es, a
@p = dso_local local_unnamed_addr global ptr addrspace(2) null, align 2

define dso_local void @test_copy(i8 noundef %c) local_unnamed_addr {
  %1 = load ptr addrspace(2), ptr @p, align 2, !invariant.load !0
  store i8 %c, ptr addrspace(2) %1, align 1
  %2 = load ptr addrspace(2), ptr @p, align 2, !invariant.load !0
  %arrayidx1 = getelementptr inbounds i8, ptr addrspace(2) %2, i16 2
  store i8 %c, ptr addrspace(2) %arrayidx1, align 1
  ret void
}

; Tests elimination of redundant MOV_es_A when preceded by an identical copy to R1.
; CHECK-LABEL: _test_copy_2
; CHECK: mov es, a
; CHECK-NOT: mov es, a
@p2 = dso_local local_unnamed_addr global ptr addrspace(2) null, align 2

define dso_local void @test_copy_2() local_unnamed_addr {
  %call = tail call i8 @getc() 
  %1 = load ptr addrspace(2), ptr @p2, align 2, !invariant.load !0
  store i8 %call, ptr addrspace(2) %1, align 1
  %2 = load ptr addrspace(2), ptr @p2, align 2, !invariant.load !0
  %arrayidx1 = getelementptr inbounds i8, ptr addrspace(2) %2, i16 2
  store i8 %call, ptr addrspace(2) %arrayidx1, align 1
  ret void
}

declare dso_local i8 @getc(...) local_unnamed_addr #1

attributes #1 = { "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0,+relax" }

!0 = !{}
