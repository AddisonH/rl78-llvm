; RUN: llc -verify-machineinstrs -mtriple=rl78 -mattr=+far-code -O2 < %s | FileCheck %s

; With far code, a 16-bit pointer to a function (a C++ vtable slot, a pointer
; to member function) is a plain 16-bit reference: the linker points it at a
; trampoline in near code when the function is above 64 KiB. A call through
; one goes to page 0: CALL rp uses CS, which far indirect calls change.

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16-P3"

declare i16 @f() addrspace(3)

; CHECK-LABEL: _vcall:
; CHECK:       mov cs, #0
; CHECK-NEXT:  call ax
define i16 @vcall(ptr %slot) addrspace(3) {
  %fn = load ptr, ptr %slot, align 2
  %r = call addrspace(0) i16 %fn()
  ret i16 %r
}

; CHECK-LABEL: _memptr:
; CHECK:       movw ax, #_f
define i16 @memptr() addrspace(3) {
  ret i16 ptrtoint (ptr addrspace(3) @f to i16)
}

; CHECK-LABEL: _voidptr:
; CHECK:       movw ax, #_f
define ptr @voidptr() addrspace(3) {
  ret ptr addrspacecast (ptr addrspace(3) @f to ptr)
}

; CHECK-LABEL: _vtable:
; CHECK-NEXT:  .short _f
@vtable = constant [1 x ptr] [ptr addrspacecast (ptr addrspace(3) @f to ptr)]

; The two halves of a far pointer keep their operators.
; CHECK-LABEL: _farptr:
; CHECK-NEXT:  .short LOWW(_f)
; CHECK-NEXT:  .byte LOW(HIGHW(_f))
@farptr = global ptr addrspace(3) @f
