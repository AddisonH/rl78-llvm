; Test the LowerCMP0 function.
; Ensure the CMP0_r instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _aa:
; CHECK: ; %bb.0:
; CHECK: 	cmp0 a
; CHECK: 	bnz $.LBB0_1
; CHECK: ; %bb.2:
; CHECK: 	clrw ax
; CHECK: 	mov a, x
; CHECK: 	ret
; CHECK: .LBB0_1:
; CHECK: 	onew ax
; CHECK: 	mov a, x
; CHECK: 	ret

define dso_local i8 @aa(i8 noundef %0) local_unnamed_addr #0 {
  %2 = icmp ne i8 %0, 0
  %3 = zext i1 %2 to i8
  ret i8 %3
}
