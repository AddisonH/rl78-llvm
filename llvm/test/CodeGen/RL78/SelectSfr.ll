; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_SelectSfr
; CHECK: _test_SelectSfr:{{.*}}; @test
; CHECK-NEXT:	.cfi_startproc
; CHECK-NEXT: ; %bb.0:
; CHECK-NEXT: mov a, 0xfffbc
define dso_local i8 @test_SelectSfr() local_unnamed_addr {
  %val = load i8, ptr inttoptr (i16 u0xFFBC to ptr), align 1
  ret i8 %val
}
