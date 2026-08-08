; Test the LowerCallCSRP function.
; Ensure the CALL_cs_rp instruction is lowered correctly.

; This file tests the LowerCallCSRP function using the CALL_cs_rp instruction.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _aa:
; CHECK: 	mov cs, a
; CHECK: 	call de

define dso_local void @aa(ptr addrspace(3) nocapture noundef readonly %0) local_unnamed_addr addrspace(3) #0 {
  tail call addrspace(3) void %0() #1
  ret void
}
