; Test the LowerSELECTCC function.
; Ensure the SELECTCCBTBF16_imm_imm instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _am:
; CHECK: ; %bb.0:
; CHECK: 	mov a, x
; CHECK: 	bf a.3, $.LBB0_1
; CHECK: ; %bb.2:
; CHECK: 	movw ax, #4369
; CHECK: 	ret
; CHECK: .LBB0_1:
; CHECK: 	movw ax, #8738
; CHECK: 	ret

define dso_local i16 @am(i16 noundef %0, i8 noundef %1) local_unnamed_addr #0 {
  %3 = and i16 %0, 8
  %4 = icmp eq i16 %3, 0
  %5 = select i1 %4, i16 8738, i16 4369
  ret i16 %5
}
