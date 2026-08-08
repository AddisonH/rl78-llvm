; This test verifies the presence of the TRUNC operation performed on the ADDRSPACECAST node.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_cast:
; CHECK-NEXT: 	.cfi_startproc
; CHECK-NEXT: ; %bb.0:
; CHECK-NEXT: 	movw ax, #LOWW(_far_variable)
; CHECK-NEXT:  	ret

@far_variable = external dso_local addrspace(2) global i16, align 2

define dso_local ptr @test_cast() #0 {
  ret ptr addrspacecast (ptr addrspace(2) @far_variable to ptr)
}
