; Test the LowerUMUL_LOHI16 function.
; Ensure the UMUL_LOHI_16_r_r instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _main:
; CHECK: ; %bb.0:
; CHECK: 	mov x, #79
; CHECK: 	mov c, a
; CHECK: 	mulu x ; x, a, a, x
; CHECK: 	mov x, #26

define dso_local i8 @main(i8 %input) local_unnamed_addr {
  %1 = urem i8 %input, 26
  %2 = add nuw nsw i8 %1, 97
  ret i8 %2
}
