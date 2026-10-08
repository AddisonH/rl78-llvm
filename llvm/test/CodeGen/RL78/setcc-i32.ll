; RUN: llc -mtriple=rl78 -O2 -rl78-select-to-branch=false < %s | FileCheck %s

; An ordered i32 compare producing a value compares the high halves (signed:
; with the XOR1 fixup), then on equality the low halves into the same flags,
; and selects once: one CMPW per half and a single conditional branch.

; CHECK-LABEL: _sgt:
; CHECK:       cmpw ax, hl
; CHECK-NEXT:  xor1 cy, a.7
; CHECK-NEXT:  mov a, h
; CHECK-NEXT:  xor1 cy, a.7
; CHECK-NEXT:  movw ax, [sp+0]
; CHECK-NEXT:  sknz
; CHECK-NEXT:  cmpw ax, de
; CHECK-NEXT:  bh
; CHECK-NOT:   cmpw
; CHECK-NOT:   and
; CHECK:       ret
define i16 @sgt(i32 %a, i32 %b) {
  %c = icmp sgt i32 %a, %b
  %z = zext i1 %c to i16
  ret i16 %z
}

; CHECK-LABEL: _ule:
; CHECK:       cmpw ax, hl
; CHECK-NEXT:  movw ax, [sp+0]
; CHECK-NEXT:  sknz
; CHECK-NEXT:  cmpw ax, bc
; CHECK-NEXT:  bnh
; CHECK-NOT:   cmpw
; CHECK:       ret
define i16 @ule(i32 %a, i32 %b) {
  %c = icmp ule i32 %a, %b
  %z = zext i1 %c to i16
  ret i16 %z
}

; CHECK-LABEL: _sel:
; CHECK:       cmpw ax, de
; CHECK-NEXT:  xor1 cy, a.7
; CHECK-NEXT:  mov a, d
; CHECK-NEXT:  xor1 cy, a.7
; CHECK:       sknz
; CHECK-NEXT:  cmpw ax, hl
; CHECK-NOT:   cmpw
; CHECK:       ret
define i16 @sel(i32 %a, i32 %b, i16 %x, i16 %y) {
  %c = icmp slt i32 %a, %b
  %s = select i1 %c, i16 %x, i16 %y
  ret i16 %s
}
