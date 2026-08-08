; This test verifies the lowering of a truncating store.

; RUN: llc -mtriple=rl78 -mattr=+far-data %s -o - | FileCheck %s

; CHECK: _test_trunc_store:
; CHECK: 	movw de, ax
; CHECK: 	mov a, c
; CHECK: 	mov es:[hl+2], a

define dso_local void @test_trunc_store(i32 %val, ptr %ptr) {
  %trunc = trunc i32 %val to i24
  store i24 %trunc, ptr %ptr, align 4
  ret void
}
