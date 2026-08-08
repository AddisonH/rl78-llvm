; This test verifies that the STORE8_stack_slot_imm instruction is not outlined when
; the stack offset, along with the 4 bytes from the CALL instruction, does not
; fit in the 8 bit displacement limit.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _store8_sequence_a:
; CHECK: 	mov [sp+252], #-86
; CHECK: 	call !_OUTLINED_FUNCTION_0

; CHECK: _store8_sequence_b:
; CHECK: 	mov [sp+252], #-86
; CHECK: 	call !_OUTLINED_FUNCTION_0

; CHECK: _OUTLINED_FUNCTION_0:
; CHECK: 	mov [sp+255], #-86
; CHECK: 	mov [sp+254], #-86
; CHECK: 	mov [sp+253], #-86
; CHECK: 	ret

define dso_local void @store8_sequence_a() #0 {
  %1 = alloca [300 x i8], align 1
  %2 = getelementptr inbounds [300 x i8], ptr %1, i16 0, i16 249
  %3 = getelementptr inbounds [300 x i8], ptr %1, i16 0, i16 250
  %4 = getelementptr inbounds [300 x i8], ptr %1, i16 0, i16 251
  %5 = getelementptr inbounds [300 x i8], ptr %1, i16 0, i16 252
  store i8 -86, ptr %2, align 1
  store i8 -86, ptr %3, align 1
  store i8 -86, ptr %4, align 1
  store i8 -86, ptr %5, align 1
  ret void
}

define dso_local void @store8_sequence_b() #0 {
  %1 = alloca [300 x i8], align 1
  %2 = getelementptr inbounds [300 x i8], ptr %1, i16 0, i16 249
  %3 = getelementptr inbounds [300 x i8], ptr %1, i16 0, i16 250
  %4 = getelementptr inbounds [300 x i8], ptr %1, i16 0, i16 251
  %5 = getelementptr inbounds [300 x i8], ptr %1, i16 0, i16 252
  store i8 -86, ptr %2, align 1
  store i8 -86, ptr %3, align 1
  store i8 -86, ptr %4, align 1
  store i8 -86, ptr %5, align 1
  ret void
}

attributes #0 = { optsize }
