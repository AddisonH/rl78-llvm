; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s

; A constant address in the short direct area (FFE20H to FFF1FH), as in a
; register written "(*(volatile unsigned char *)0xFFE30)", uses the saddr
; forms. A word at an odd address is stored as two bytes.

define void @bytes() {
; CHECK-LABEL: _bytes:
; CHECK:       oneb 0xfff00
; CHECK-NEXT:  inc 0xffe30
; CHECK-NEXT:  clrb 0xffe31
; CHECK-NEXT:  mov 0xffe40, #5
; CHECK-NEXT:  ret
  store volatile i8 1, ptr inttoptr (i16 -256 to ptr), align 1
  %v = load volatile i8, ptr inttoptr (i16 -464 to ptr), align 1
  %inc = add i8 %v, 1
  store volatile i8 %inc, ptr inttoptr (i16 -464 to ptr), align 1
  store volatile i8 0, ptr inttoptr (i16 -463 to ptr), align 1
  store volatile i8 5, ptr inttoptr (i16 -448 to ptr), align 1
  ret void
}

define void @words() {
; CHECK-LABEL: _words:
; CHECK:       movw 0xffe40, #4660
; CHECK-NEXT:  movw ax, #4660
; CHECK-NEXT:  mov 0xffe42, a
; CHECK-NEXT:  mov a, x
; CHECK-NEXT:  mov 0xffe41, a
; CHECK-NEXT:  ret
  store volatile i16 4660, ptr inttoptr (i16 -448 to ptr), align 2
  store volatile i16 4660, ptr inttoptr (i16 -447 to ptr), align 1
  ret void
}

define i16 @load(i16 %x) {
; CHECK-LABEL: _load:
; CHECK:       addw ax, 0xffe50
; CHECK-NEXT:  ret
  %v = load volatile i16, ptr inttoptr (i16 -432 to ptr), align 2
  %r = add i16 %v, %x
  ret i16 %r
}

; Below the area: an ordinary absolute address.
define void @outside() {
; CHECK-LABEL: _outside:
; CHECK:       mov !0xffe1f, #2
; CHECK-NEXT:  ret
  store volatile i8 2, ptr inttoptr (i16 -481 to ptr), align 1
  ret void
}
