; Test the LowerAndOrXor16_rp_rp function.
; Ensure the XOR16_rp_rp instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _aa:
; CHECK: 	xor a, b
; CHECK: 	xch a, x
; CHECK: 	xor a, c
; CHECK: 	xch a, x

define dso_local i16 @aa(i16 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = xor i16 %0, %1
  ret i16 %3
}
