; Test the LowerShift_Or_LowerRotate_rp_rp function.
; Ensure the SHLW_rp_rp instruction is lowered correctly.

; RUN: llc -verify-machineinstrs -mtriple=rl78 %s -o - | FileCheck %s

; CHECK-LABEL: _ab:
; CHECK:       [[LOOP:\.LBB0_[0-9]+]]:{{.*}}Inner Loop Header
; CHECK:       shlw ax, 1
; CHECK:       dec c
; CHECK-NEXT:  bnz $[[LOOP]]

define dso_local void @ab(ptr nocapture noundef %0, ptr nocapture noundef readonly %1) local_unnamed_addr #0 {
  %3 = load i16, ptr %0, align 1
  %4 = load i16, ptr %1, align 1
  %5 = shl i16 %3, %4
  store i16 %5, ptr %0, align 1
  ret void
}
