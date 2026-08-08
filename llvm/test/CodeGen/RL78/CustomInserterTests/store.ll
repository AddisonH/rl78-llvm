; Test the Lower8bitASrc function.
; Ensure the STORE8_memBorCi_imm instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

@p = dso_local local_unnamed_addr global i8 0, align 1

; CHECK: _ad:
; CHECK: 	mov b, a
; CHECK: 	mov LOWW(_p)[b], #2

define dso_local void @ad(i8 noundef %0) local_unnamed_addr #0 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds i8, ptr @p, i16 %2
  store i8 2, ptr %3, align 1
  ret void
}
