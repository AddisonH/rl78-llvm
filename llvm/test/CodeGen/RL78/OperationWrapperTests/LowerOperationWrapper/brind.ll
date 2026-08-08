; This test verifies the lowering of an i32 BRIND.

; RUN: llc -mtriple=rl78 -mattr=+far-data %s -o - | FileCheck %s

@main.b = internal global [2 x ptr] [ptr blockaddress(@main, %3), ptr blockaddress(@main, %2)], align 2

define dso_local ptr @temp(ptr nocapture noundef readonly %0) local_unnamed_addr #0 {
  %2 = load ptr, ptr %0, align 2
  ret ptr %2
}

; CHECK: _main:
; CHECK: ; %bb.0:
; CHECK: 	mov cs, a
; CHECK: 	movw ax, de
; CHECK: 	br ax

define dso_local i16 @main() #1 {
  %1 = tail call ptr @temp(ptr noundef nonnull @main.b)
  indirectbr ptr %1, [label %3, label %2]

2:
  br label %3

3:
  %4 = phi i16 [ 1, %2 ], [ 0, %0 ]
  ret i16 %4
}
