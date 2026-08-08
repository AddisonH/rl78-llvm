; Test the LowerShiftOrRotateForSpeed function.
; Ensure the SHLW_rp_rp instruction is lowered correctly when -O3 is used.

; RUN: llc -mtriple=rl78 -O3 %s -o - | FileCheck %s

; CHECK: _ab:
; CHECK:  shl b, 5
; CHECK:  sknc
; CHECK:  shlw ax, 8
; CHECK:  shl b, 1
; CHECK:  sknc
; CHECK:  shlw ax, 4
; CHECK:  shl b, 1
; CHECK:  sknc
; CHECK:  shlw ax, 2

define dso_local void @ab(ptr nocapture noundef %0, ptr nocapture noundef readonly %1) local_unnamed_addr #0 {
  %3 = load i16, ptr %0, align 1
  %4 = load i16, ptr %1, align 1
  %5 = shl i16 %3, %4
  store i16 %5, ptr %0, align 1
  ret void
}
