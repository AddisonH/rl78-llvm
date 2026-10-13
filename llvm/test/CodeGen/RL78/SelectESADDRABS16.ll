; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@g = dso_local local_unnamed_addr global i8 0, align 1

; CHECK-LABEL: _test_SelectESADDRABS16
; CHECK: mov a, es:!LOWW(_g)
define dso_local i8 @test_SelectESADDRABS16() local_unnamed_addr  {
  %1 = load i8, ptr addrspace(2) addrspacecast (ptr @g to ptr addrspace(2)), align 1
  ret i8 %1
}

; CHECK-LABEL: _test_SelectESADDRABS16_offset
; CHECK: mov a, es:!LOWW(_g+3)
define dso_local i8 @test_SelectESADDRABS16_offset() local_unnamed_addr {
  %ptr = getelementptr i8, ptr @g, i16 3
  %ptr_es = addrspacecast ptr %ptr to ptr addrspace(2)
  %val = load i8, ptr addrspace(2) %ptr_es, align 1
  ret i8 %val
}
