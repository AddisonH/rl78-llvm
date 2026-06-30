; Ensure set1/clr1 are emitted in valid cases and absent otherwise.

; RUN: llc < %s -mtriple=rl78 | FileCheck %s

; CHECK-LABEL: set1_byte_and:
define void @set1_byte_and(i8* %p) {
  ; CHECK:      set1 [{{.*}}].3
  %v = load volatile i8, i8* %p
  %or = or i8 %v, 8
  store volatile i8 %or, i8* %p
  ret void
}


; CHECK-LABEL: clr1_byte_and:
define void @clr1_byte_and(i8* %p) {
  ; CHECK:      clr1 [{{.*}}].5
  %v = load volatile i8, i8* %p
  %and = and i8 %v, -33      ; ~(1<<5)
  store volatile i8 %and, i8* %p
  ret void
}

; CHECK-LABEL: set1_low_byte_of_i16:
define void @set1_low_byte_of_i16(i16* %p) {
  ; CHECK:      set1 [{{.*}}].2
  %v = load i16, i16* %p
  %or = or i16 %v, 4
  store i16 %or, i16* %p
  ret void
}

; CHECK-LABEL: clr1_low_byte_of_i16:
define void @clr1_low_byte_of_i16(i16* %p) {
  ; CHECK:      clr1 [{{.*}}].7
  %v = load i16, i16* %p
  %and = and i16 %v, -129    ; ~(1<<7)
  store i16 %and, i16* %p
  ret void
}

; CHECK-LABEL: high_byte_of_i16:
define void @high_byte_of_i16(i16* %p) {
  ; CHECK:  incw ax
  ; CHECK-NEXT:  movw hl, ax
  ; CHECK-NEXT:  set1 [{{.*}}].0
  %v = load i16, i16* %p
  %or = or i16 %v, 256
  store i16 %or, i16* %p
  ret void
}

; CHECK-LABEL: no_volatile_i16
define void @no_volatile_i16(ptr %p) {
; CHECK-NOT: set1
; CHECK-NOT: clr1
  %v = load volatile i16, ptr %p
  %t = or i16 %v, 1
  store volatile i16 %t, ptr %p
  ret void
}

; CHECK-LABEL: no_multi_bit
define void @no_multi_bit(i8* %p) {
; CHECK-NOT: set1
; CHECK-NOT: clr1
  %v = load i8, i8* %p
  %t = or i8 %v, 12
  store i8 %t, i8* %p
  ret void
}

; CHECK-LABEL: no_multiple_uses
define void @no_multiple_uses(i8* %p, i8* %q) {
; CHECK-NOT: set1
; CHECK-NOT: clr1
  %v = load volatile i8, i8* %p
  store volatile i8 %v, i8* %q
  %t = or i8 %v, 1
  store volatile i8 %t, i8* %p
  ret void
}

; CHECK-LABEL: no_different_addr
define void @no_different_addr(i8* %a, i8* %b) {
; CHECK-NOT: set1
; CHECK-NOT: clr1
  %v = load volatile i8, i8* %a
  %t = or i8 %v, 2
  store volatile i8 %t, i8* %b
  ret void
}
