; Test the Lower16bitAXSrc, LowerESSrc functions.
; Ensure INC_memri, INC_esaddr16 instructions are lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

@xa = dso_local local_unnamed_addr addrspace(2) global [1 x i8] zeroinitializer, align 1

; CHECK: _aa:
; CHECK: 	movw hl, ax
; CHECK: 	inc [hl+3]

define dso_local i8 @aa(ptr nocapture noundef %0) local_unnamed_addr #0 {
  %2 = getelementptr inbounds i8, ptr %0, i16 3
  %3 = load i8, ptr %2, align 1
  %4 = add i8 %3, 1
  store i8 %4, ptr %2, align 1
  ret i8 0
}

; CHECK: _ac:
; CHECK: 	mov es, #HIGHW(_xa)
; CHECK: 	inc es:!LOWW(_xa+3)

define dso_local i8 @ac() local_unnamed_addr #1 {
  %1 = load i8, ptr addrspace(2) getelementptr inbounds ([1 x i8], ptr addrspace(2) @xa, i16 3, i16 0), align 1
  %2 = add i8 %1, 1
  store i8 %2, ptr addrspace(2) getelementptr inbounds ([1 x i8], ptr addrspace(2) @xa, i16 3, i16 0), align 1
  ret i8 0
}
