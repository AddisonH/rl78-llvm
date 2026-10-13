; A 32-bit multiply is a call to __COM_lmul for size and three MULHU for speed.

; RUN: llc -verify-machineinstrs -mtriple=rl78 %s -o - | FileCheck %s

@wk_slDATA = dso_local local_unnamed_addr global i32 -4096, align 2
@wk_slANS = dso_local global i32 0, align 2

; CHECK: _Arithmetic100gl:
; CHECK: ; %bb.0:
; CHECK: 	call !__COM_lmul

define dso_local void @Arithmetic100gl() local_unnamed_addr optsize {
  %1 = load i32, ptr @wk_slDATA, align 2
  %2 = mul nsw i32 %1, %1
  store volatile i32 %2, ptr @wk_slANS, align 2
  ret void
}

; CHECK: _speed:
; CHECK-NOT: __COM_lmul
; CHECK: mulhu
; CHECK: mulhu
; CHECK: mulhu
; CHECK-NOT: __COM_lmul
; CHECK: ret

define dso_local i32 @speed(i32 %a, i32 %b) local_unnamed_addr {
  %m = mul i32 %a, %b
  ret i32 %m
}
