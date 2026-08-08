; This test verifies the ADD instruction inside ReplaceOperand.

; RUN: llc -mtriple=rl78 -mattr=+far-data %s -o - | FileCheck %s

; CHECK: _test_load_add_logic:
; CHECK: 	movw ax, #LOWW(_buf)
; CHECK: 	movw bc, #HIGHW(_buf)
; CHECK: 	addw ax, #64

@buf = external global [100 x i32], align 2

define i32 @test_load_add_logic() {
  %base = ptrtoint ptr @buf to i32
  %total_addr = add i32 %base, 64 
  %ptr = inttoptr i32 %total_addr to ptr
  %val = load i32, ptr %ptr, align 2
  ret i32 %val
}
