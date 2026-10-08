; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s

; Incrementing an i32 in memory: the high half only takes the carry. It is
; loaded into a register and incremented with a skip, not added byte by byte
; through A with ADDC from memory.

; CHECK-LABEL: _inc:
; CHECK:       movw ax, [hl+2]
; CHECK:       addw ax, [hl]
; CHECK-NEXT:  sknc
; CHECK:       incw bc
; CHECK-NOT:   addc
; CHECK:       ret
define void @inc(ptr %c, i16 %i) {
  %p = getelementptr inbounds i32, ptr %c, i16 %i
  %v = load i32, ptr %p, align 2
  %n = add i32 %v, 1
  store i32 %n, ptr %p, align 2
  ret void
}

; CHECK-LABEL: _dec:
; CHECK-NOT:   subc
; CHECK-NOT:   addc
; CHECK:       decw
; CHECK:       ret
define void @dec(ptr %c) {
  %v = load i32, ptr %c, align 2
  %n = add i32 %v, -3
  store i32 %n, ptr %c, align 2
  ret void
}
