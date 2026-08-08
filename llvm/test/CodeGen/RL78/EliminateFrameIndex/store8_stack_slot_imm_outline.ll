; This test verifies that the STORE8_stack_slot_imm instruction will be outlined when
; its stack offset, adjusted for the 4 extra bytes added by the CALL instruction,
; can fit in the 8 bit displacement limit.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _store8_stack_slot_imm_outline_a:
; CHECK: 	subw sp, #4
; CHECK: 	call !_OUTLINED_FUNCTION_0
; CHECK: 	addw sp, #4
; CHECK: 	ret

; CHECK: _store8_stack_slot_imm_outline_b:
; CHECK: 	subw sp, #4
; CHECK: 	call !_OUTLINED_FUNCTION_0
; CHECK: 	addw sp, #4
; CHECK: 	ret

; CHECK: _OUTLINED_FUNCTION_0:
; CHECK: 	mov [sp+5], #-86
; CHECK: 	mov [sp+4], #-86
; CHECK: 	mov [sp+6], #-86
; CHECK: 	ret

define dso_local void @store8_stack_slot_imm_outline_a() local_unnamed_addr #0 {
  %1 = alloca i8, align 1
  %2 = alloca i8, align 1
  %3 = alloca i8, align 1
  store i8 -86, ptr %1, align 1
  store i8 -86, ptr %2, align 1
  store i8 -86, ptr %3, align 1
  ret void
}

define dso_local void @store8_stack_slot_imm_outline_b() local_unnamed_addr #0 {
  %1 = alloca i8, align 1
  %2 = alloca i8, align 1
  %3 = alloca i8, align 1
  store i8 -86, ptr %1, align 1
  store i8 -86, ptr %2, align 1
  store i8 -86, ptr %3, align 1
  ret void
}

attributes #0 = { optsize }
