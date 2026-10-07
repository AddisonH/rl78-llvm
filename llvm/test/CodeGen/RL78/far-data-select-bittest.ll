; RUN: llc -mtriple=rl78 -mattr=+far-data -O2 < %s | FileCheck %s

; A load through a select of far addresses with a bit-test condition must
; keep the segment: the select stays in the compare form (LOAD_SELECTCC),
; not a bit-test select of the address halves followed by a near load.

target datalayout = "e-m:o-p0:32:16:16-A1-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"

; CHECK-LABEL: _bit_test:
; CHECK-NOT: [hl]
; CHECK: mov es, a
; CHECK: mov a, es:[hl]
; CHECK: ret
define i8 @bit_test(i8 %c, ptr %p1, ptr %p2) {
  %v1 = load i8, ptr %p1, align 1
  %v2 = load i8, ptr %p2, align 1
  %b = and i8 %c, 1
  %t = icmp ne i8 %b, 0
  %r = select i1 %t, i8 %v1, i8 %v2
  ret i8 %r
}
