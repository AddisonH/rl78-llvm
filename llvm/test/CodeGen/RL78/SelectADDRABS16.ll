; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@g = dso_local local_unnamed_addr global i8 0, align 1

; CHECK-LABEL: _test_SelectADDRABS16
; CHECK: mov a, !LOWW(_g)
define dso_local i8 @test_SelectADDRABS16() local_unnamed_addr  {
  %1 = load i8, ptr @g, align 1
  ret i8 %1
}

; CHECK-LABEL: _test_SelectADDRABS16_const
; CHECK: mov a, !0xf1234
define dso_local i8 @test_SelectADDRABS16_const() local_unnamed_addr  {
  %1 = load volatile i8, ptr inttoptr (i16 4660 to ptr), align 1
  ret i8 %1
}

; CHECK-LABEL: _test_SelectADDRABS16_sym_offset
; CHECK: mov a, !LOWW(_g+3)
define dso_local i8 @test_SelectADDRABS16_sym_offset() local_unnamed_addr {
  %ptr = getelementptr i8, ptr @g, i16 3
  %val = load i8, ptr %ptr, align 1
  ret i8 %val
}
