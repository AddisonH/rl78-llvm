; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s

; The 32-bit compare of two volatile globals: the high word of the second is
; read by the compare itself (CMPW AX, !addr16), after both words of the
; first, as the volatile order asks. Its low word is loaded before: a
; compare after SKNZ may not run, and a volatile load must.

@va = external global i32
@vb = external global i32

declare void @f()

define void @eq() {
; CHECK-LABEL: eq:
; CHECK:       movw ax, !LOWW(_va+2)
; CHECK-NEXT:  movw bc, !LOWW(_va)
; CHECK-NEXT:  movw hl, !LOWW(_vb)
; CHECK-NEXT:  cmpw ax, !LOWW(_vb+2)
; CHECK-NEXT:  movw ax, bc
; CHECK-NEXT:  sknz
; CHECK-NEXT:  cmpw ax, hl
  %a = load volatile i32, ptr @va
  %b = load volatile i32, ptr @vb
  %c = icmp eq i32 %a, %b
  br i1 %c, label %t, label %e
t:
  call void @f()
  ret void
e:
  ret void
}

; Without a branch nothing is in the way of the fold, but the low word still
; must not be read under the skip.
define i16 @lt() {
; CHECK-LABEL: lt:
; CHECK-NOT:   cmpw ax, !LOWW(_vb)
; CHECK:       sknz
; CHECK-NEXT:  cmpw ax, {{bc|de|hl}}
; CHECK-NOT:   !LOWW(_vb)
; CHECK:       ret
  %a = load volatile i32, ptr @va
  %b = load volatile i32, ptr @vb
  %c = icmp slt i32 %a, %b
  %r = zext i1 %c to i16
  ret i16 %r
}

; Not volatile: the low word may be read under the skip.
@a = external global i32
@b = external global i32
define i16 @ult_plain() {
; CHECK-LABEL: ult_plain:
; CHECK:       cmpw ax, !LOWW(_b+2)
; CHECK:       sknz
; CHECK-NEXT:  cmpw ax, !LOWW(_b)
  %x = load i32, ptr @a
  %y = load i32, ptr @b
  %c = icmp ult i32 %x, %y
  %r = zext i1 %c to i16
  ret i16 %r
}
