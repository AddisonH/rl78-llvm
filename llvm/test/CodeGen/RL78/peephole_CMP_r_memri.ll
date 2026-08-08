; Test replacement of MOV A, X + CMP A, [HL+byte] with CMPS X, [HL+byte].
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

; CHECK-LABEL: _foo:
; CHECK-NOT: cmp a, [hl+5]
; CHECK-NOT: mov a, x
; CHECK: cmps x, [hl+5]
define i16 @foo(i8 %0, i8 %1, ptr %2) {
  %4 = getelementptr inbounds i8, ptr %2, i16 5
  %5 = load i8, ptr %4, align 1
  %6 = icmp eq i8 %5, %1
  %7 = zext i1 %6 to i16
  ret i16 %7
}

; CMPS is only usable when the consumer tests Z; for CY-based conditions it has
; a different meaning, so the MOV + CMP pair must be left alone.
; CHECK-LABEL: _unsigned_lt:
; CHECK-NOT: cmps
; CHECK: cmp a, [hl+5]
define i16 @unsigned_lt(i8 %0, i8 %1, ptr %2) {
  %4 = getelementptr inbounds i8, ptr %2, i16 5
  %5 = load i8, ptr %4, align 1
  %6 = icmp ult i8 %5, %1
  %7 = zext i1 %6 to i16
  ret i16 %7
}
