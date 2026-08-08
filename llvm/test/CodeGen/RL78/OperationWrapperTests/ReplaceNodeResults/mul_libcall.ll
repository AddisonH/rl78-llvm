; This test verifies the presence of the MUL_I32 libcall (_COM_lmul).

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

@wk_slDATA = dso_local local_unnamed_addr global i32 -4096, align 2
@wk_slANS = dso_local global i32 0, align 2

; CHECK: _Arithmetic100gl:
; CHECK: ; %bb.0:
; CHECK: 	call !__COM_lmul

define dso_local void @Arithmetic100gl() local_unnamed_addr #0 {
  %1 = load i32, ptr @wk_slDATA, align 2
  %2 = mul nsw i32 %1, %1
  store volatile i32 %2, ptr @wk_slANS, align 2
  ret void
}
