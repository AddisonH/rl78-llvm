; RUN: llc -mtriple=rl78 -enable-machine-outliner < %s | FileCheck %s

; NOP_cg (__nop, asm("nop")) is never outlined, even when the same run repeats:
; an outlined call/ret would change the cycle count of a timing delay.

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-NOT: OUTLINED_FUNCTION

define void @f1() minsize {
entry:
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  ret void
}

define void @f2() minsize {
entry:
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  ret void
}

define void @f3() minsize {
entry:
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  ret void
}

declare void @llvm.rl78.nop()
