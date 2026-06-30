; Verifies if ExpandPseudoInsts optimizes a conditional branch to a 
; conditional skip when the conditional branch is the terminating
; pseudo-instruction in a basic block, and the fall-through basic block
; contains a pseudo-instruction that expands to exactly one real machine 
; instruction.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @llvm.rl78.nop()

; Generates SKZ instead of BZ.
; CHECK: _skz
; CHECK: cmpw ax, #0
; CHECK: skz
; CHECK: nop
; CHECK: .LBB0_2:
; CHECK: ret
define void @skz(i16 %cond) {
entry:
  %tobool.not = icmp eq i16 %cond, 0
  br i1 %tobool.not, label %if.end, label %if.then

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKNZ instead of BNZ.
; CHECK: _sknz
; CHECK: cmpw ax, #0
; CHECK: sknz
; CHECK: ret
; CHECK: .LBB1_1:
; CHECK: nop
; CHECK: ret
define void @sknz(i16 %cond) {
entry:
  %tobool.not = icmp eq i16 %cond, 0
  br i1 %tobool.not, label %if.end, label %if.then, !prof !0

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKC instead of BC.
; CHECK: _skc
; CHECK: cmpw ax, bc
; CHECK: skc
; CHECK: nop
; CHECK: .LBB2_2:
; CHECK: ret
define void @skc(i16 %a, i16 %b) {
entry:
  %cmp.not = icmp ult i16 %a, %b
  br i1 %cmp.not, label %if.end, label %if.then

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKNC instead of BNC.
; CHECK: _sknc
; CHECK: cmpw ax, bc
; CHECK: sknc
; CHECK: nop
; CHECK: .LBB3_2:
; CHECK: ret
define void @sknc(i16 %a, i16 %b) {
entry:
  %cmp = icmp ult i16 %a, %b
  br i1 %cmp, label %if.then, label %if.end

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKH instead of BH.
; CHECK: _skh
; CHECK: cmpw ax, bc
; CHECK: skh
; CHECK: ret
; CHECK: .LBB4_1:
; CHECk: nop
; CHECK: ret
define void @skh(i16 %a, i16 %b) {
entry:
  %cmp = icmp ugt i16 %a, %b
  br i1 %cmp, label %if.then, label %if.end, !prof !1

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKNH instead of BNH.
; CHECK: _sknh
; CHECK: cmpw ax, bc
; CHECK: sknh
; CHECK: ret
; CHECK: .LBB5_1:
; CHECK: nop
; CHECK: ret
define void @sknh(i16 %a, i16 %b) {
entry:
  %cmp.not = icmp ugt i16 %a, %b
  br i1 %cmp.not, label %if.end, label %if.then, !prof !0

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

!0 = !{!"branch_weights", i32 2000, i32 1}
!1 = !{!"branch_weights", i32 1, i32 2000}
