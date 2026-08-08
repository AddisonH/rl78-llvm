; This test verifies the EXTRACT_ELEMENT with empty OpResults.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_add:
; CHECK: ; %bb.0:
; CHECK: 	movw de, ax
; CHECK: 	addw ax, bc
; CHECK: 	cmpw ax, de
; CHECK: 	xor1 cy, a.7
; CHECK: 	movw hl, ax

define dso_local i16 @test_add(i16 noundef %0, i16 noundef %1, ptr nocapture noundef writeonly %2) local_unnamed_addr #0 {
  %4 = tail call { i16, i1 } @llvm.sadd.with.overflow.i16(i16 %0, i16 %1)
  %5 = extractvalue { i16, i1 } %4, 1
  %6 = extractvalue { i16, i1 } %4, 0
  store i16 %6, ptr %2, align 2
  %7 = zext i1 %5 to i16
  ret i16 %7
}

declare { i16, i1 } @llvm.sadd.with.overflow.i16(i16, i16) #1
