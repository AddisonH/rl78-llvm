; This test verifies the i32 and i64 BSWAPs.
; The i64 variant recursively emits EXTRACT_ELEMENTs as it performs swaps on each half before recombining them.
; The i32 variant just swaps the high part with the low part of the node. 

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _aa:
; CHECK: ; %bb.0:
; CHECK: 	movw hl, ax
; CHECK: 	movw ax, [sp+4]
; CHECK: 	xch a, x ;bswap ax
; CHECK: 	movw [hl+6], ax
; CHECK: 	movw ax, [sp+6]
; CHECK: 	xch a, x ;bswap ax
; CHECK: 	movw [hl+4], ax
; CHECK: 	movw ax, [sp+8]
; CHECK: 	xch a, x ;bswap ax
; CHECK: 	movw [hl+2], ax
; CHECK: 	movw ax, [sp+10]
; CHECK: 	xch a, x ;bswap ax

define dso_local void @aa(ptr noalias nocapture writeonly sret(i64) align 2 %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = tail call i64 @llvm.bswap.i64(i64 %1)
  store i64 %3, ptr %0, align 2
  ret void
}

declare i64 @llvm.bswap.i64(i64) #1

; CHECK: _ab:
; CHECK: ; %bb.0:
; CHECK: 	xch a, x
; CHECK: 	xchw ax, bc
; CHECK: 	xch a, x
; CHECK: 	ret

define dso_local i32 @ab(i32 noundef %0) local_unnamed_addr #2 {
  %2 = tail call i32 @llvm.bswap.i32(i32 %0)
  ret i32 %2
}

declare i32 @llvm.bswap.i32(i32) #1
