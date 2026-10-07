; RUN: llc -mtriple=rl78 -mattr=+far-data -O2 < %s | FileCheck %s

; A select between two loads whose condition is a truncated bool (no setcc)
; must still become a load through a selected address: one far load, not two
; speculated loads and a select.

target datalayout = "e-m:o-p0:32:16:16-A1-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"

; CHECK-LABEL: _value_or:
; CHECK: mov a, es:[hl+2]
; CHECK: cmp0 a
; CHECK: movw ax, es:[hl]
; CHECK-NOT: es:
; CHECK: ret
define i16 @value_or(ptr nonnull align 2 dereferenceable(3) %e, ptr nonnull align 2 dereferenceable(2) %d) {
  %hp = getelementptr inbounds nuw i8, ptr %e, i32 2
  %h = load i8, ptr %hp, align 2, !range !0, !noundef !1
  %c = trunc nuw i8 %h to i1
  %v = load i16, ptr %e, align 2
  %w = load i16, ptr %d, align 2
  %r = select i1 %c, i16 %v, i16 %w
  ret i16 %r
}

!0 = !{i8 0, i8 2}
!1 = !{}
