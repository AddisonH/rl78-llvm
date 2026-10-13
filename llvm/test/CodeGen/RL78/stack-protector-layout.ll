; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s

; The frame is laid out upwards from SP, so the stack protector's guard has
; to be its last object, with the array right below it: an overflow of the
; array then reaches the guard before the slot that holds %dest, which the
; function still uses before it checks the guard.

declare void @copy(ptr, ptr)

define void @smash(ptr %source, ptr %dest) sspreq {
; CHECK-LABEL: _smash:
; CHECK:       subw sp, #54
; The guard, at the top of the frame.
; CHECK:       movw ax, !LOWW(___stack_chk_guard)
; CHECK-NEXT:  movw [sp+52], ax
; The array is at [sp+4], %dest is kept below it.
; CHECK:       addw ax, #4
; CHECK:       call !_copy
; CHECK:       movw ax, [sp+2]
; CHECK-NEXT:  call !_copy
; CHECK:       movw ax, [sp+52]
; CHECK:       call !___stack_chk_fail
entry:
  %local = alloca [48 x i8], align 1
  call void @copy(ptr %local, ptr %source)
  call void @copy(ptr %dest, ptr %local)
  ret void
}
