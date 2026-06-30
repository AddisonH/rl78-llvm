; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Verifies DAGCombine/ISel for AND (~X & ~Y) change to ~(X | Y).
; CHECK-LABEL: _test_DAGCombine_AND
; CHECK: or a, b
; CHECK: xch a, x
; CHECK: or a, c
; CHECK: xch a, x
; CHECK: movw bc, ax
; CHECK: movw ax, #65535
; CHECK: subw ax, bc
; CHECK: ret
define i16 @test_DAGCombine_AND(i16 %a, i16 %b) {
  %1 = xor i16 %a, -1
  %2 = xor i16 %b, -1
  %3 = and i16 %1, %2
  ret i16 %3
}

; Verifies DAGCombine/ISel for AND (~X & Y) change to ((X | Y) - X).
; CHECK-LABEL: _test_DAGCombine_AND2
; CHECK: movw de, ax
; CHECK-NEXT: or a, b
; CHECK-NEXT: xch a, x
; CHECK-NEXT: or a, c
; CHECK-NEXT: xch a, x
define i16 @test_DAGCombine_AND2(i16 %x, i16 %y) {
  %nx = xor i16 %x, -1
  %r  = and i16 %nx, %y
  ret i16 %r
}

; Verifies DAGCombine/ISel for AND  (X & ~Y) change to (X - (X & Y)).
; CHECK-LABEL: _test_DAGCombine_AND3
; CHECK: movw de, ax
; CHECK-NEXT: and a, b
; CHECK-NEXT: xch a, x
; CHECK-NEXT: and a, c
; CHECK-NEXT: xch a, x
define i16 @test_DAGCombine_AND3(i16 %x, i16 %y) {
  %ny = xor i16 %y, -1
  %r  = and i16 %x, %ny
  ret i16 %r
}

; Verifies DAGCombine/ISel for AND switch of AND and SHL. 
; CHECK: 	clrb a
; CHECK-NEXT:	addw ax, ax
; CHECK-NEXT:	ret
define i16 @test_AND_SHL(i16 %a) {
  %sh = shl i16 %a, 1
  %r  = and i16 %sh, 510   ; 0x01FE
  ret i16 %r
}
