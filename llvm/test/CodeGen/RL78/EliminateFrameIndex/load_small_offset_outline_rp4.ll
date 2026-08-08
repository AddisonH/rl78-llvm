; This test verifies the instructions added when the Frame Register is RP4 in the case
; of LOAD / STORE instructions.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_load_RP4:
; CHECK: 	push hl
; CHECK: 	movw ax, [sp+10]
; CHECK: 	movw hl, ax
; CHECK: 	movw ax, [hl+22]
; CHECK: 	pop hl

; CHECK: 	push hl
; CHECK: 	movw ax, [sp+10]
; CHECK: 	movw hl, ax
; CHECK: 	movw ax, [hl+20]
; CHECK: 	pop hl

; CHECK: 	push hl
; CHECK: 	movw ax, [sp+10]
; CHECK: 	movw hl, ax
; CHECK: 	movw ax, [hl+18]
; CHECK: 	pop hl

; CHECK: 	push hl
; CHECK: 	movw ax, [sp+10]
; CHECK: 	movw hl, ax
; CHECK: 	movw ax, [hl+16]
; CHECK: 	pop hl

define dso_local void @test_load_RP4(<2 x float> noundef %0) local_unnamed_addr #0 {
  %2 = alloca <2 x float>, align 8
  store <2 x float> %0, ptr %2, align 8
  ret void
}
