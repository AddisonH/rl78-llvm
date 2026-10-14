; RUN: llc -verify-machineinstrs -mtriple=rl78 -O2 < %s | FileCheck %s

; i32 multiplies whose operands are known (not just explicitly zero-extended)
; to fit in 8 bits use MULU, and those of 16-bit operands MULHU_cg; neither calls
; __COM_lmul (CoreMark matrix_mul_matrix_bitextract). An i16 multiply of
; values only known to fit in 8 bits stays MULHU_cg: MULU's A/X operands cost
; more moves. One with an operand masked to a byte is MULU.

; CHECK-LABEL: _bitfields:
; CHECK:       mulu x
; CHECK-NOT:   __COM_lmul
; CHECK:       ret
define i32 @bitfields(i32 %t, i32 %acc) {
  %a = lshr i32 %t, 2
  %a4 = and i32 %a, 15
  %b = lshr i32 %t, 5
  %b7 = and i32 %b, 127
  %m = mul nuw nsw i32 %a4, %b7
  %r = add i32 %m, %acc
  ret i32 %r
}

; CHECK-LABEL: _masked16:
; CHECK:       mulu x
; CHECK-NOT:   mulhu
; CHECK:       ret
define i16 @masked16(i16 %a, i16 %b) {
  %x = and i16 %a, 15
  %y = and i16 %b, 255
  %m = mul i16 %x, %y
  ret i16 %m
}

; CHECK-LABEL: _known16:
; CHECK:       mulhu
; CHECK-NOT:   mulu
; CHECK:       ret
define i16 @known16(i16 %a, i16 %b) {
  %x = and i16 %a, 15
  %y = lshr i16 %b, 9
  %m = mul i16 %x, %y
  ret i16 %m
}

; CHECK-LABEL: _wide:
; CHECK:       mulhu
; CHECK-NOT:   __COM_lmul
; CHECK:       ret
define i32 @wide(i32 %a, i32 %b) {
  %x = and i32 %a, 4095
  %y = and i32 %b, 65535
  %m = mul i32 %x, %y
  ret i32 %m
}
