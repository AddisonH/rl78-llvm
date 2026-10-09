; 16-bit AND/OR/XOR stay one pseudo on AX until after allocation, where they
; become a byte at a time through A and XCH A, X.
; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s

@g = global i16 0

; The Z flag the expansion leaves is that of the low byte only, so the
; compare with 0 must stay (the pseudo does not define Zflag).
; CHECK-LABEL: _and_eq0:
; CHECK:      and a, b
; CHECK-NEXT: xch a, x
; CHECK-NEXT: and a, c
; CHECK-NEXT: xch a, x
; CHECK-NEXT: cmpw ax, #0
define void @and_eq0(i16 %x, i16 %y) {
  %a = and i16 %x, %y
  %c = icmp eq i16 %a, 0
  br i1 %c, label %t, label %e
t:
  store i16 %a, ptr @g
  ret void
e:
  ret void
}

; CHECK-LABEL: _or_imm:
; CHECK:      xch a, x
; CHECK-NEXT: or a, #52
; CHECK-NEXT: xch a, x
; CHECK-NEXT: or a, #18
define i16 @or_imm(i16 %x) {
  %r = or i16 %x, 4660
  ret i16 %r
}
