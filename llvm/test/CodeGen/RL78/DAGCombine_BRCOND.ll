; RUN: llc -mtriple=rl78 < %s | FileCheck %s 
target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_DAGCombine_BRCOND
; CHECK: 	cmpw ax, hl
; CHECK-NEXT:	xor1 cy, a.7
; CHECK-NEXT:	mov a, h
; CHECK-NEXT:	xor1 cy, a.7
; CHECK-NEXT:	movw ax, [sp+0]
; CHECK-NEXT:	sknz
; CHECK-NEXT:	cmpw ax, de
@gsink = global i16 0

define void @test_DAGCombine_BRCOND(i32 %x, i32 %y) {
  %cmp = icmp slt i32 %x, %y
  br i1 %cmp, label %t, label %ret

t:
  call void asm sideeffect "", ""()
  br label %ret

ret:
  ret void
}
