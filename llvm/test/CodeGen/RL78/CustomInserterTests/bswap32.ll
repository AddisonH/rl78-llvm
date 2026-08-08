; Test the LowerBSWAP32 function.
; Ensure the BSWAP32_rp instruction is lowered correctly.

; This file tests the LowerBSWAP32 function using the BSWAP32_rp instruction.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _ap:
; CHECK: 	xch a, x
; CHECK: 	xchw ax, bc
; CHECK: 	xch a, x

define dso_local i32 @ap(i32 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 @llvm.bswap.i32(i32 %0)
  ret i32 %2
}

declare i32 @llvm.bswap.i32(i32) #1
