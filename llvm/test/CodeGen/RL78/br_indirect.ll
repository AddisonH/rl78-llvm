; Test basic block that ends in indirect branch. 
; Ensure that analyzeBranch reports this terminator cannot be analyzed and removeBranch/insertBranch is never called.
; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

define void @test_indirect(i8* %ptr) {
; CHECK-LABEL: _test_indirect:
; CHECK-NEXT: .cfi_startproc
; CHECK-NEXT: ; %bb.0: 
; CHECK-NEXT: br ax
; CHECK-NEXT: .LBB0_1:
; CHECK-NEXT: ret
; CHECK-NEXT: .Lfunc_end0:
bb0:
  indirectbr i8* %ptr, [label %bb1, label %bb2]

bb1:
  ret void

bb2:
  ret void
}
