; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

%struct.S5 = type { i8, i8, i8, i8, i8 }

@__const.ret5.s = private unnamed_addr constant %struct.S5 { i8 1, i8 2, i8 3, i8 4, i8 5 }, align 1

; Returns 1 byte (i8) in register A
; CHECK-LABEL: _i8
; CHECK: mov a, #7
define dso_local i8 @i8() local_unnamed_addr  {
  ret i8 7
}

; Returns 2 bytes in register AX.
; CHECK-LABEL: _i16
; CHECK: movw ax, #7
define dso_local i16 @i16() local_unnamed_addr  {
  ret i16 7
}

; Returns 3 bytes in registers C-AX.
; CHECK-LABEL: _ret3
; CHECK: oneb x
; CHECK-NEXT: mov c, #3
; CHECK-NEXT: mov a, #2
define dso_local [3 x i8] @ret3() local_unnamed_addr  {
  ret [3 x i8] c"\01\02\03"
}

declare void @llvm.memcpy.p0.p0.i16(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i16, i1 immarg) #1

; Returns 4 bytes in registers BC-AX.
; CHECK-LABEL: _ret4
; CHECK: oneb x
; CHECK-NEXT: mov c, #3
; CHECK-NEXT: mov b, #4
; CHECK-NEXT: mov a, #2
define dso_local [4 x i8] @ret4() local_unnamed_addr  {
  ret [4 x i8] c"\01\02\03\04"
}

; Returns two i16 values in registers BC-AX.
; CHECK-LABEL: _ret4w
; CHECK: movw bc, #8738
; CHECK-NEXT: movw ax, #4369
define dso_local [2 x i16] @ret4w() local_unnamed_addr  {
  ret [2 x i16] [i16 4369, i16 8738]
}

; Returns 5 bytes via compiler generated argument.
; CHECK-LABEL: _ret5
; CHECK: movw hl, ax
; CHECK-NEXT: mov [hl+4], #5
; CHECK-NEXT: mov [hl+3], #4
; CHECK-NEXT: mov [hl+2], #3
; CHECK-NEXT: mov [hl+1], #2
; CHECK-NEXT: mov [hl], #1
define dso_local void @ret5(ptr noalias nocapture writeonly sret(%struct.S5) align 1 %0) local_unnamed_addr #2 {
  tail call void @llvm.memcpy.p0.p0.i16(ptr noundef nonnull align 1 dereferenceable(5) %0, ptr noundef nonnull align 1 dereferenceable(5) @__const.ret5.s, i16 5, i1 false)
  ret void
}

; Returns a far pointer in registers A-DE.
; CHECK-LABEL: _ret_far
; CHECK: movw de, #9029
; CHECK-NEXT: oneb a
define dso_local nonnull ptr addrspace(2) @ret_far() local_unnamed_addr {
  ret ptr addrspace(2) inttoptr (i32 74565 to ptr addrspace(2))
}
