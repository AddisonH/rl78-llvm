; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"


; Instruction "setJmp" is illegal to outline, no _OUTLINED_FUNCTION_0 should be present in assembly file.
; CHECK-LABEL: _test_setjmp
; CHECK-NOT: !_OUTLINED_FUNCTION_0
; CHECK: _test_setjmp:{{.*}}; @test_setjmp
; CHECK:	call !_setjmp
define dso_local i16 @test_setjmp(ptr noundef %env) local_unnamed_addr{
  %call = call i16 @setjmp(ptr noundef %env)
  ret i16 %call
}

declare dso_local i16 @setjmp(ptr noundef) local_unnamed_addr 

; CHECK-LABEL: _test_setjmp_2
; CHECK-NOT: !_OUTLINED_FUNCTION_0
; CHECK: _test_setjmp_2:{{.*}}; @test_setjmp_2
; CHECK:	call !_setjmp
define dso_local i16 @test_setjmp_2(ptr noundef %env) local_unnamed_addr {
  %call = call i16 @setjmp(ptr noundef %env)
  ret i16 %call
}
