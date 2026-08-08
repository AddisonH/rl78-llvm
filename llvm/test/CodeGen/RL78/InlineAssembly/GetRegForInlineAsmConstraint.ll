; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_weight_r_16:
; CHECK: 	;APP
; CHECK: 	addw ax, ax
; CHECK: 	;NO_APP
define dso_local i16 @test_weight_r_16(i16 noundef returned %0) local_unnamed_addr #0 {
  tail call void asm sideeffect "addw ax, $0", "r"(i16 %0) #1
  ret i16 %0
}

; CHECK: _test_weight_r_8:
; CHECK: 	;APP
; CHECK: 	.local	@$IMM_5
; CHECK: .set @$IMM_5, 5
; CHECK: 	mov a, #5
; CHECK: 	;NO_APP
define dso_local i8 @test_weight_r_8(i8 noundef returned %0) local_unnamed_addr #0 {
  tail call void asm sideeffect "mov $0, #5", "r"(i8 %0) #1
  ret i8 %0
}
