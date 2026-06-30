; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@p2 = dso_local local_unnamed_addr addrspace(2) global [222 x i8] zeroinitializer, align 1

; CHECK-LABEL: _test_SelectESADDRr8i16
; CHECK: mov es, #HIGHW(_p2)
; CHECK-NEXT: mov b, a
; CHECK-NEXT: mov a, es:LOWW(_p2)[b]
define dso_local i8 @test_SelectESADDRr8i16(i8 noundef %0) local_unnamed_addr {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds [222 x i8], ptr addrspace(2) @p2, i16 0, i16 %2
  %4 = load i8, ptr addrspace(2) %3, align 1
  ret i8 %4
}
