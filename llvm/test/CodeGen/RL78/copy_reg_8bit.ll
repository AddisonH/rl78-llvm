; RUN: llc -march=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _test_A_r:
; CHECK:       mov a, x
; CHECK-NEXT:  ret
define dso_local i8 @test_A_r(i8 noundef %0, i8 noundef returned %1) {
  ret i8 %1
}

; CHECK-LABEL: _test_r_A:
; CHECK:       mov x, a
define dso_local void @test_r_A(i8 noundef %0) #1 {
  %tmp = alloca i8, align 1
  store i8 %0, ptr %tmp, align 1
  %val = load i8, ptr %tmp, align 1
  call void @callee2(i8 noundef 0, i8 noundef %val)
  ret void
}

; CHECK-LABEL: _test_r_r_size:
; CHECK:       push ax
; CHECK-NEXT:  mov a, c
; CHECK-NEXT:  mov b, a
; CHECK-NEXT:  pop ax
; CHECK:       br !_callee_rr
define dso_local i8 @test_r_r_size(i8 noundef %a, i8 noundef %b, i8 noundef %c) local_unnamed_addr #0 {
  %r = tail call i8 @callee_rr(i8 noundef %a, i8 noundef %c, i8 noundef %b)
  ret i8 %r
}

; CHECK-LABEL: _test_r_r_speed:
; CHECK-NOT:   push ax
; CHECK-NOT:   pop ax
; CHECK:       xch a, b
; CHECK:       xch a, c
; CHECK:       br !_callee_rr
define dso_local i8 @test_r_r_speed(i8 noundef %a, i8 noundef %b, i8 noundef %c) local_unnamed_addr #2 {
  %r = tail call i8 @callee_rr(i8 noundef %a, i8 noundef %c, i8 noundef %b)
  ret i8 %r
}
define dso_local i8 @callee_rr(i8 noundef %a, i8 noundef %b, i8 noundef %c) local_unnamed_addr #2 {
  %t = add i8 %a, %b
  %u = add i8 %t, %c
  ret i8 %u
}

declare dso_local void @callee2(i8 noundef, i8 noundef)
declare dso_local void @callee4(i8 noundef, i8 noundef,
                                i8 noundef, i8 noundef)

attributes #0 = { optsize }
attributes #1 = { noinline optnone }
attributes #2 = { noinline nounwind }



