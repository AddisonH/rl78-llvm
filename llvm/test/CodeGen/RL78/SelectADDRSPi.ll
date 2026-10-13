; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Checks direct local variable access (FrameIndex).
; CHECK-LABEL: _test_SelectADDRSPi
; CHECK: subw sp, #4
; CHECK-NEXT: movw ax, sp
; CHECK-NEXT: call !_f
; CHECK-NEXT: mov a, [sp+0]
; CHECK-NEXT: addw sp, #4
; CHECK-NEXT: ret
define dso_local i8 @test_SelectADDRSPi() local_unnamed_addr {
  %arr = alloca [4 x i8], align 1
  call void @f(ptr noundef nonnull %arr) 
  %1 = load i8, ptr %arr, align 1
  ret i8 %1
}

declare dso_local void @f(ptr noundef) local_unnamed_addr 

; Checks direct stack access via FrameIndex.
; CHECK-LABEL: _test_SelectADDRSPi2
; CHECK: mov [sp+2], #7
define dso_local i8 @test_SelectADDRSPi2() {
  %1 = alloca [4 x i8], align 1
  %2 = getelementptr inbounds [4 x i8], ptr %1, i16 0, i16 2
  store i8 7, ptr %2, align 1
  %3 = getelementptr inbounds [4 x i8], ptr %1, i16 0, i16 2
  %4 = load i8, ptr %3, align 1
  ret i8 %4
}
