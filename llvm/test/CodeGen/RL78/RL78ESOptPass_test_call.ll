; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Tests elimination of redundant ES initializations is not done with call as a barrier.
; CHECK-LABEL: _test_call
; CHECK:	mov a, x
; CHECK-NEXT:	mov es, a
; CHECK-NEXT: movw ax, bc
; CHECK-NEXT:	movw es:[hl], ax
; CHECK-NEXT:	call !_foo
; CHECK-NEXT:	movw hl, !LOWW(_p)
; CHECK-NEXT:	movw ax, !LOWW(_p+2)
; CHECK-NEXT:	mov a, x
; CHECK-NEXT:	mov es, a
; CHECK-NEXT:	movw ax, [sp+0]
; CHECK-NEXT:	movw es:[hl+4], ax

@p = dso_local local_unnamed_addr global ptr addrspace(2) null, align 2

define dso_local void @test_call(i16 noundef %x) local_unnamed_addr{

  %1 = load ptr addrspace(2), ptr @p, align 2
  store volatile i16 %x, ptr addrspace(2) %1, align 2
  tail call void @foo() #2
  %2 = load ptr addrspace(2), ptr @p, align 2
  %arrayidx1 = getelementptr inbounds i16, ptr addrspace(2) %2, i16 2
  store volatile i16 %x, ptr addrspace(2) %arrayidx1
  ret void
}

declare dso_local void @foo(...) local_unnamed_addr #1
