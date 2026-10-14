; RUN: not llc -mtriple=rl78 %s 2>&1 -o - | FileCheck %s

; A memory operand is [DE] or [HL]; the 32-bit address of __far data is not
; one. SelectionDAGBuilder reports it instead of asserting.

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"

@y = addrspace(2) global i16 0, align 2

; CHECK: error: invalid operand for inline asm constraint 'm'
; CHECK: error: invalid operand for inline asm constraint 'm'
define void @far_mem() {
  call void asm sideeffect "", "=*m"(ptr addrspace(2) elementtype(i16) @y)
  call void asm sideeffect "", "*m"(ptr addrspace(2) elementtype(i16) @y)
  ret void
}
