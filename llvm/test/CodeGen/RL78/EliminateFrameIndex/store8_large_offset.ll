; This test verifies the STORE8_stack_slot_imm instruction when stack offset is too large ( > 255 )
; for a direct addressing MOV, so an indirect store is performed then the value is restored back into BC. 

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _store8_large_offset:
; CHECK:	push bc
; CHECK:	movw bc, sp
; CHECK:	mov 258[bc], #-86
; CHECK:	pop bc

define dso_local void @store8_large_offset() local_unnamed_addr #0 {
  %1 = alloca [300 x i8], align 1
  %2 = getelementptr inbounds [300 x i8], ptr %1, i16 0, i16 256
  store i8 -86, ptr %2, align 1
  ret void
}

attributes #0 = { optsize }
