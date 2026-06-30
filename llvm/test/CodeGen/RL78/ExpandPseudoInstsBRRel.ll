; Verifies that the ExpandPseudoInsts pass correctly creates relative
; unconditional branch instructions.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @padding_function(i64, i64, i64, i64)
declare void @llvm.rl78.nop()

; Generates a short relative unconditional backward branch.
; CHECK: _br_rel8_backward_jump
; CHECK: br $.LBB0_1
define void @br_rel8_backward_jump() {
entry:
  br label %while.body

while.body:
  call void @llvm.rl78.nop()
  br label %while.body
}

; Generates a long relative unconditional backward branch.
; CHECK: _br_rel16_backward_jump
; CHECK: br $!.LBB1_1
define void @br_rel16_backward_jump() {
entry:
  br label %while.body

while.body:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  br label %while.body
}
