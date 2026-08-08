; This test verifies that -1 is returned when __divul is called with 0 as a dividend.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _main:
; CHECK: ; %bb.0:
; CHECK: 	movw bc, #-1
; CHECK: 	movw ax, #-1
; CHECK: 	ret

define dso_local i32 @main() #0 {
  %1 = call i32 @llvm.rl78.divul(i32 5, i16 0)
  ret i32 %1
}

declare i32 @llvm.rl78.divul(i32, i16) #1
