; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_constraint_r_u8:
; CHECK: 	;APP
; CHECK: 	.local	@$IMM_5
; CHECK: .set @$IMM_5, 5
; CHECK: 	add a, #5
; CHECK: 	;NO_APP
define dso_local i8 @test_constraint_r_u8(i8 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i8 asm sideeffect "add $0, #5", "=r"() #2
  ret i8 %2
}

; CHECK: _test_matching:
; CHECK: 	;APP
; CHECK: 	add a, #5
; CHECK: 	;NO_APP
define dso_local i8 @test_matching(i8 noundef %0) local_unnamed_addr #1 {
  %2 = tail call i8 asm "add $0, #5", "={r1}"() #3
  ret i8 %2
}
