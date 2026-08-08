; This test verifies that the HighValue for an i32 ADDRSPACECAST is 0 when IsSrcAddress is true.
; The outcome should be an i32 BUILD_PAIR made out of the low address of the function and 0.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

define dso_local void @target_function() #0 {
  ret void
}

; CHECK: _get_func_as_far_data:
; CHECK: ; %bb.0:
; CHECK: 	movw de, #LOWW(_target_function)
; CHECK: 	clrb a
; CHECK: 	ret

define dso_local ptr addrspace(2) @get_func_as_far_data() local_unnamed_addr #2 {
  ret ptr addrspace(2) addrspacecast (ptr addrspace(3) addrspacecast (ptr @target_function to ptr addrspace(3)) to ptr addrspace(2))
}
