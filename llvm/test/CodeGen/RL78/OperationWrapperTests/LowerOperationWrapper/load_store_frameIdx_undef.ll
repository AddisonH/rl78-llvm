; This test verifies the lowering of STORE and LOAD instructions with i16 FrameIndex pointers paired with
; i32 UNDEF offsets.

; RUN: llc -mtriple=rl78 -mattr=+far-data %s -o - | FileCheck %s

; CHECK: _test_store_and_load:
; CHECK: 	movw ax, #5
; CHECK: 	movw [sp+0], ax
; CHECK: 	movw ax, sp
; CHECK: 	movw ax, [sp+0]

declare void @escape(ptr noundef)

define dso_local i16 @test_store_and_load() local_unnamed_addr #0 {
  %1 = alloca i16, align 2
  store i16 5, ptr %1, align 2
  call void @escape(ptr %1)
  %2 = load i16, ptr %1, align 2
  ret i16 %2
}
