; -rl78-virtual-acc: a read of A (or X) alone of a value in AX is the
; subregister of its virtual register, so the value of a signed 16-bit
; compare (CMPW AX, #imm; XOR1 CY, A.7) need not stay in physical AX.
; RUN: llc -mtriple=rl78 -O2 -rl78-virtual-acc -stop-before=register-coalescer < %s | FileCheck %s

@g = global i16 0

; CHECK-LABEL: name: f
; CHECK: CMPW_rp_imm [[V:%[0-9]+]], 6, 1
; CHECK-NEXT: XOR1_cy_r killed [[V]].sub_hi, 7
define void @f(ptr %p) {
  %v = load i16, ptr %p
  %c = icmp sgt i16 %v, 5
  br i1 %c, label %t, label %e
t:
  store i16 %v, ptr @g
  ret void
e:
  ret void
}
