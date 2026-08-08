; Test the LowerEXTEND function.
; Ensure the ZEXT_8_16 instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _shift_right_by_x_places:
; CHECK: 	mov x, a
; CHECK: 	clrb a

define dso_local i8 @shift_right_by_x_places(i8 noundef %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = zext i8 %0 to i16
  %4 = lshr i16 %3, %1
  %5 = trunc i16 %4 to i8
  ret i8 %5
}
