; Test basic block that ends in a single conditional branch.
; Ensure the branch is analyzed correctly and removed.
; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

define void @cond_branch(i1 %cond) {
; CHECK-LABEL: _cond_branch:
; CHECK-NEXT: .cfi_startproc
; CHECK-NEXT: ; %bb.0: 
; CHECK-NEXT: ret
; CHECK-NEXT: .Lfunc_end0:
; CHECK-NOT: {{[[:space:]]}}b{{[a-z]+}}

bb0:
  br i1 %cond, label %bb1, label %bb2

bb1:
  ret void

bb2:
  ret void
}
