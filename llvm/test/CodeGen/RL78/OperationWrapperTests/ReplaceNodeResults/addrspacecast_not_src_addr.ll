; This test verifies when IsSrcAddress is false inside ReplaceNodeResults for an ADDRSPACECAST.
; If the address is null, the HighValue will be 0; if the address is not null, it will be 15.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _func:
; CHECK: 	cmpw ax, #0
; CHECK: 	clrw ax
; CHECK: 	skz ;#.LBB0_2
; CHECK: ; %bb.1:
; CHECK: 	movw ax, #15

define dso_local void @func() local_unnamed_addr #1 {
  %1 = load ptr addrspace(1), ptr @func, align 2
  %2 = addrspacecast ptr addrspace(1) %1 to ptr addrspace(2)
  store ptr addrspace(2) null, ptr addrspace(2) %2, align 2
  ret void
}
