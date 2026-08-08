; Test the Lower8BitOpAA and Lower16BitOpAXAX functions.
; Ensure ADD_r_memri and ADDW_rp_imm instructions are lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _ab:
; CHECK: 	add a, [hl+3]

define dso_local i8 @ab(ptr nocapture noundef readonly %0) local_unnamed_addr #0 {
  %2 = getelementptr inbounds i8, ptr %0, i16 3
  %3 = load i8, ptr %2, align 1
  %4 = add i8 %3, 5
  ret i8 %4
}

; CHECK: _ac:
; CHECK: 	addw ax, #5

define dso_local i16 @ac(i16 noundef %0) local_unnamed_addr #1 {
  %2 = add i16 %0, 5
  ret i16 %2
}
