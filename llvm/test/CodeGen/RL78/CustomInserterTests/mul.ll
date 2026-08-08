; Test the LowerMUL16 function.
; Ensure MUL16_rp_rp_S1_S2 instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _aa:
; CHECK: 	xch a, c
; CHECK: 	movw de, ax
; CHECK: 	xch a, b
; CHECK: 	mulu x
; CHECK: 	xchw ax, bc
; CHECK: 	mulu x
; CHECK: 	xchw ax, de
; CHECK: 	mulu x
; CHECK: 	add a, e
; CHECK: 	add a, c

define dso_local i16 @aa(i16 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = mul i16 %0, %1
  ret i16 %3
}

attributes #0 = { "target-cpu"="RL78_S1" }
