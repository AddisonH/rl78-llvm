; This test checks a global address of type i32.
; It breaks down the address into two i16 parts, producing LOWW and HIGHW instructions.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _main:
; CHECK: ; %bb.0:
; CHECK: 	movw ax, #LOWW(_f)
; CHECK: 	movw bc, #HIGHW(_f)

declare dso_local i16 @f(...) addrspace(3)

define dso_local i32 @main() local_unnamed_addr {
  %ptr = ptrtoint ptr addrspace(3) @f to i32
  ret i32 %ptr
}
