; Test the LowCMPW_rp_imm switch case.
; Ensure the instruction is lowered correctly by the custom inserter.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

@y = dso_local addrspace(2) global i8 0, section ".bssf_ATEFFFF", align 1 #0

; CHECK: _main:
; CHECK: 	movw ax, #LOWW(_y)
; CHECK: 	sknz
; CHECK: 	cmpw ax, #20

define dso_local i16 @main() #1 {
  %y_addr = ptrtoint ptr addrspace(2) @y to i32
  %cmp1 = icmp ne i32 %y_addr, 20
  br i1 %cmp1, label %ret1, label %ret0

ret1:
  ret i16 1

ret0:
  ret i16 0
}
