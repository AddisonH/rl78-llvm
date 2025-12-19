; RUN: llc %s -o - | FileCheck %s

target triple = "rl78"

define i32 @_xbegin() {
entry:
  %res = alloca i32, align 4
  store i32 -1, ptr %res, align 4
  call void asm sideeffect ".byte 0xC7\0A\09.byte 0xF8\0A\09.byte 2\0A\09.byte 0\0A\09.byte 0\0A\09.byte 0\0A\09br $$.L__MSASMLABEL_.0__L2\0A\09movw ax, #123\0A\09.L__MSASMLABEL_.0__L2:", ""()
  %0 = load i32, ptr %res, align 4
  ret i32 %0
}

; CHECK-NOT: Error parsing inline asm

; CHECK-LABEL: __xbegin:
; CHECK: br $.L__MSASMLABEL_.0__L2
; CHECK: .L__MSASMLABEL_.0__L2:
