; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@var = dso_local local_unnamed_addr global i16 10, align 2 #0

; CHECK-LABEL: _test_SelectSaddr
; CHECK: movw ax, _var
; CHECK: .section	.sdata,"aw",@progbits
define dso_local i16 @test_SelectSaddr() local_unnamed_addr {
  %1 = load i16, ptr @var, align 2
  ret i16 %1
}

attributes #0 = { "saddr" }
