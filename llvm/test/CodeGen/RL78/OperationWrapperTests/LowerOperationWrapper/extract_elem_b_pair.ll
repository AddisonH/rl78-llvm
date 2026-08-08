; This test verifies that when an i32 EXTRACT_ELEMENT out of an BUILD_PAIR appears, with the 2nd operand
; of the BUILD_PAIR being an i32 constant value, the whole BUILD_PAIR is replaced with the constant value.

; RUN: llc -mtriple=rl78 -mattr=+far-data %s -o - | FileCheck %s

define dso_local void @foo(ptr nocapture readnone %0, ptr nocapture noundef writeonly %1, i1 %2, i1 %3) local_unnamed_addr #0 {
  ret void
}

; CHECK: _main:
; CHECK: 	mov x, #15

define dso_local i16 @main() local_unnamed_addr #2 {
  %1 = alloca [64 x i8], align 1, addrspace(1)
  %2 = addrspacecast ptr addrspace(1) %1 to ptr
  call void @foo(ptr poison, ptr noundef %2, i1 poison, i1 poison) #4
  ret i16 0
}
