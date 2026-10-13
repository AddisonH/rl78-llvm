; A variable 16-bit shift whose result must be in AX (here for the store) has
; the class RL78AXRP, not RL78RPRegs; the inserter
; for speed (-O3) must still shift in AX, not in A.
; RUN: llc -verify-machineinstrs -mtriple=rl78 -O3 < %s | FileCheck %s

@g = global i16 0

; CHECK-LABEL: _shl16_store:
; CHECK: shlw ax, 8
; CHECK: addw ax, ax
; CHECK-NEXT: movw !LOWW(_g), ax
define void @shl16_store(i16 %a, i8 %n) {
  %c = zext i8 %n to i16
  %r = shl i16 %a, %c
  store i16 %r, ptr @g
  ret void
}
