; `x > 0` on an int is CMPW AX, #0 + XOR1 CY, A.7, which
; RL78InsertExchangeInstructions shortens to ADDW AX, AX when AX is dead
; afterwards. XOR1 reads only A, so X (the low byte) must be dead as well.
; In f the low byte is still needed as the shift count; the allocator keeps
; the value in BC and compares a copy, which may then be doubled.
; RUN: llc -mtriple=rl78 -O3 < %s | FileCheck %s

@shift = global i16 1
@res = global i16 0

; CHECK-LABEL: _f:
; CHECK: movw bc, !LOWW(_shift)
; CHECK-NEXT: movw ax, bc
; CHECK-NEXT: addw ax, ax
; CHECK-NEXT: bnh
define void @f() {
  %s = load i16, ptr @shift
  %c = icmp sgt i16 %s, 0
  br i1 %c, label %then, label %end

then:
  %r = lshr i16 8, %s
  store i16 %r, ptr @res
  br label %end

end:
  ret void
}

; With AX dead after the compare the shorter form is still used.
; CHECK-LABEL: _g:
; CHECK: movw ax, !LOWW(_shift)
; CHECK-NEXT: addw ax, ax
; CHECK-NEXT: bnh
define void @g() {
  %s = load i16, ptr @shift
  %c = icmp sgt i16 %s, 0
  br i1 %c, label %then, label %end

then:
  store i16 4, ptr @res
  br label %end

end:
  ret void
}
