; This test verifies the lowering of an i32 call instruction. It should introduce a far branch.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _main:
; CHECK: ; %bb.0:
; CHECK: 	br !!_f

define dso_local i16 @main() local_unnamed_addr #0 {
  %1 = tail call addrspace(3) i16 @f() #2
  ret i16 %1
}

declare dso_local i16 @f() local_unnamed_addr addrspace(3) #1
