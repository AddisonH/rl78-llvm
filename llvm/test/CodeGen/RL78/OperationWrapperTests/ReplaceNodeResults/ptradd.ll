; This test verifies the i32 PTRADD, which returns the unchanged high part and the sum consisting of the
; pointer's low part and its offset.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _foo:
; CHECK: ; %bb.0:
; CHECK: 	addw ax, de
; CHECK: 	movw hl, ax
; CHECK: 	clrb a
; CHECK: 	mov a, c
; CHECK: 	mov es, a
; CHECK: 	mov a, es:[hl+1]
; CHECK: 	ret

define dso_local i8 @foo(i16 noundef %0, ptr addrspace(2) nocapture noundef readonly %1) local_unnamed_addr #0 {
  %3 = add nsw i16 %0, 1
  %4 = getelementptr inbounds i8, ptr addrspace(2) %1, i16 %3
  %5 = load i8, ptr addrspace(2) %4, align 1
  ret i8 %5
}
