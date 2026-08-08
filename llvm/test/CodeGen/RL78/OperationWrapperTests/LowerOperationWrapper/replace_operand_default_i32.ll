; This test verifies the default implementation inside ReplaceOperand.

; RUN: llc -mtriple=rl78 -mattr=+far-data %s -o - | FileCheck %s

; CHECK: _test_load:
; CHECK: 	movw ax, es:[hl]
; CHECK: 	movw de, ax
; CHECK: 	movw ax, es:[hl+2]
; CHECK: 	movw bc, ax
; CHECK: 	movw ax, de

define i32 @test_load(i32 %0) {
  %p = inttoptr i32 %0 to ptr
  %v = load i32, ptr %p, align 2
  ret i32 %v
}
