; This test verifies the lowering of a truncating store.

; RUN: llc -mtriple=rl78 -mattr=+far-data %s -o - | FileCheck %s

; CHECK: _test_non_trunc_store:
; CHECK: 	movw ax, #42
; CHECK: 	movw [sp+0], ax

declare void @escape(ptr)

define dso_local i16 @test_non_trunc_store() local_unnamed_addr #0 {
  %1 = alloca i16, align 2
  store i16 42, ptr %1, align 2
  %2 = load i16, ptr %1, align 2
  ret i16 %2
}

attributes #0 = { optsize }
