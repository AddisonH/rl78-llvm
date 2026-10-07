; RUN: llc -mtriple=rl78 -mattr=+far-data -addr-sink-using-gep=false < %s | FileCheck %s

; A negative constant offset from a far pointer (sunk by CodeGenPrepare as an
; integer add, as the driver's -addr-sink-using-gep=false does) is added to
; the low 16 bits only. It reached SelectionDAG::getConstant as a 32-bit
; two's complement value and asserted (newlib _realloc_r with -mfar-data).

; CHECK-LABEL: _negofs:
; CHECK: movw ax, de
; CHECK-NEXT: decw ax
; CHECK-NEXT: decw ax
; CHECK-NEXT: movw hl, ax
; CHECK: mov es, a
; CHECK-NEXT: movw ax, es:[hl]
; CHECK: movw es:[hl], ax
define ptr @negofs(ptr %p) {
entry:
  %size = getelementptr i8, ptr %p, i32 -2
  %v = load i16, ptr %size, align 2
  %z = icmp eq i16 %v, 0
  br i1 %z, label %ret, label %clear

clear:
  store i16 0, ptr %size, align 2
  br label %ret

ret:
  ret ptr null
}
