; Test the LowerAndOrXor16_rp_imm, LowerAndOrXor16_rp_memri, LowerAndOrXor16_rp_abs16 functions.
; Ensure AND16_rp_imm, AND16_rp_memri, AND16_rp_abs16 instructions are lowered correctly.

; There is one more function (LowerAndOrXor16_rp_rp) which is tested in
; "xor.ll" (instruction XOR16_rp_rp).

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

@xb = dso_local local_unnamed_addr global i16 0, align 2

; CHECK: _ai:
; CHECK: 	and a, [hl+11]
; CHECK: 	xch a, x
; CHECK: 	and a, [hl+10]
; CHECK: 	xch a, x

define dso_local i16 @ai(i16 noundef %0, ptr nocapture noundef readonly %1) local_unnamed_addr #0 {
  %3 = getelementptr inbounds i16, ptr %1, i16 5
  %4 = load i16, ptr %3, align 2
  %5 = and i16 %4, %0
  ret i16 %5
}


; CHECK: _ak:
; CHECK: 	xch a, x
; CHECK: 	and a, #4
; CHECK: 	xch a, x
; CHECK: 	clrb a

define dso_local i16 @ak(i16 noundef %0) local_unnamed_addr #1 {
  %2 = and i16 %0, 4
  ret i16 %2
}


; CHECK: _am:
; CHECK: 	and a, !LOWW(_xb+1)
; CHECK: 	xch a, x
; CHECK: 	and a, !LOWW(_xb)
; CHECK: 	xch a, x

define dso_local i16 @am(i16 noundef %0) local_unnamed_addr #2 {
  %2 = load i16, ptr @xb, align 2
  %3 = and i16 %2, %0
  ret i16 %3
}
