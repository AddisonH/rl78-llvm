; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s  > %t && FileCheck %s < %t

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

%struct.Big = type { [300 x i8] }

; If the callframe is too big no _OUTLINED_FUNCTION_0 should be present in assembly file. 
; CHECK-LABEL: _test_bigCallFrameSize
; CHECK-NOT: _OUTLINED_FUNCTION_0
; CHECK: _funct2:{{.*}}; @funct2
; CHECK: movw ax, sp
; CHECK: subw ax
; CHECK: movw sp, ax
; CHECK: call !_test_bigCallFrameSize
; CHECK: call !_test_bigCallFrameSize

define dso_local void @test_bigCallFrameSize([300 x i8] %0) #0 {
  %2 = alloca %struct.Big, align 1
  %3 = alloca i8, align 1
  %4 = getelementptr inbounds %struct.Big, ptr %2, i32 0, i32 0
  store [300 x i8] %0, ptr %4, align 1
  %5 = getelementptr inbounds %struct.Big, ptr %2, i32 0, i32 0
  %6 = getelementptr inbounds [300 x i8], ptr %5, i16 0, i16 0
  %7 = load i8, ptr %6, align 1
  store volatile i8 %7, ptr %3, align 1
  ret void
}

define dso_local i16 @funct() #0 {
  %1 = alloca %struct.Big, align 1
  %2 = alloca %struct.Big, align 1
  call void @llvm.memset.p0.i64(ptr align 1 %1, i8 0, i64 300, i1 false)
  %3 = getelementptr inbounds %struct.Big, ptr %1, i32 0, i32 0
  %4 = getelementptr inbounds [300 x i8], ptr %3, i16 0, i16 0
  %5 = getelementptr inbounds %struct.Big, ptr %1, i32 0, i32 0
  %6 = load [300 x i8], ptr %5, align 1
  call void @test_bigCallFrameSize([300 x i8] %6)
  call void @llvm.memset.p0.i64(ptr align 1 %2, i8 0, i64 300, i1 false)
  %7 = getelementptr inbounds %struct.Big, ptr %2, i32 0, i32 0
  %8 = getelementptr inbounds [300 x i8], ptr %7, i16 0, i16 0
  %9 = getelementptr inbounds %struct.Big, ptr %2, i32 0, i32 0
  %10 = load [300 x i8], ptr %9, align 1
  call void @test_bigCallFrameSize([300 x i8] %10)
  ret i16 0
}

declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg) #1

define dso_local i16 @funct2() #0 {
  %1 = alloca %struct.Big, align 1
  %2 = alloca %struct.Big, align 1
  call void @llvm.memset.p0.i64(ptr align 1 %1, i8 0, i64 300, i1 false)
  %3 = getelementptr inbounds %struct.Big, ptr %1, i32 0, i32 0
  %4 = getelementptr inbounds [300 x i8], ptr %3, i16 0, i16 0
  %5 = getelementptr inbounds %struct.Big, ptr %1, i32 0, i32 0
  %6 = load [300 x i8], ptr %5, align 1
  call void @test_bigCallFrameSize([300 x i8] %6)
  call void @llvm.memset.p0.i64(ptr align 1 %2, i8 0, i64 300, i1 false)
  %7 = getelementptr inbounds %struct.Big, ptr %2, i32 0, i32 0
  %8 = getelementptr inbounds [300 x i8], ptr %7, i16 0, i16 0
  %9 = getelementptr inbounds %struct.Big, ptr %2, i32 0, i32 0
  %10 = load [300 x i8], ptr %9, align 1
  call void @test_bigCallFrameSize([300 x i8] %10)
  ret i16 0
}
