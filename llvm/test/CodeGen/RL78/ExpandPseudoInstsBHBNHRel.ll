; Verifies that the ExpandPseudoInsts pass correctly creates relative
; conditional branch if higher than (BH) and branch if not higher than 
; (BNH) instructions.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @llvm.rl78.nop()
declare void @padding_function(i64, i64, i64, i64)

; Generates a short relative conditional BH backward branch.
; CHECK: _bh_rel8_backward_jump
; CHECK: cmpw ax, bc
; CHECK: bh $.LBB0_1
define void @bh_rel8_backward_jump(i16 %current, i16 %limit) {
entry:
  br label %do.body

do.body:
  %current.addr.0 = phi i16 [ %current, %entry ], [ %dec, %do.body ]
  call void @llvm.rl78.nop()
  %dec = add i16 %current.addr.0, -1
  %cmp = icmp ugt i16 %dec, %limit
  br i1 %cmp, label %do.body, label %do.end

do.end:
  ret void
}

; Generates a short relative conditional BH forward branch.
; CHECK: _bh_rel8_forward_jump
; CHECK: cmpw ax, bc
; CHECK: bh $.LBB1_1
define void @bh_rel8_forward_jump(i16 %a, i16 %b) {
entry:
  %cmp = icmp ugt i16 %a, %b
  br i1 %cmp, label %if.then, label %if.end, !prof !0

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  call void @llvm.rl78.nop()
  ret void
}

; Generates SKNH and BR $!addr20 as the backward jump distance exceeds what 
; BH $addr20 can handle.
; CHECK: _br_rel16_bh_backward_jump_substitute
; CHECK: cmpw ax, bc
; CHECK: sknh
; CHECK: br $!.LBB2_1
define void @br_rel16_bh_backward_jump_substitute(i16 %current, i16 %limit) {
entry:
  br label %do.body

do.body:
  %current.addr.0 = phi i16 [ %current, %entry ], [ %dec, %do.body ]
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %dec = add i16 %current.addr.0, -1
  %cmp = icmp ugt i16 %dec, %limit
  br i1 %cmp, label %do.body, label %do.end

do.end:
  ret void
}

; Generates SKNH and BR $!addr20 as the forward jump distance exceeds what 
; BH $addr20 can handle.
; CHECK: _br_rel16_bh_forward_jump_substitute
; CHECK: cmpw ax, bc
; CHECK: sknh
; CHECK: br $!.LBB3_1
define void @br_rel16_bh_forward_jump_substitute(i16 %a, i16 %b) {
entry:
  %cmp = icmp ugt i16 %a, %b
  br i1 %cmp, label %if.then, label %if.end, !prof !0

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  ret void
}

; Generates a short relative conditional BNH backward branch.
; CHECK: _bnh_rel8_backward_jump
; CHECK: cmpw ax, bc
; CHECK: bnh $.LBB4_1
define void @bnh_rel8_backward_jump(i16 %current, i16 %limit) {
entry:
  br label %do.body

do.body:
  %current.addr.0 = phi i16 [ %current, %entry ], [ %dec, %do.body ]
  call void @llvm.rl78.nop()
  %dec = add i16 %current.addr.0, -1
  %cmp.not = icmp ugt i16 %dec, %limit
  br i1 %cmp.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates a short relative conditional BNH forward branch.
; CHECK: _bnh_rel8_forward_jump
; CHECK: cmpw ax, bc
; CHECK: bnh $.LBB5_1
define void @bnh_rel8_forward_jump(i16 %a, i16 %b) {
entry:
  %cmp.not = icmp ugt i16 %a, %b
  br i1 %cmp.not, label %if.end, label %if.then, !prof !1

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  call void @llvm.rl78.nop()
  ret void
}

; Generates SKH and BR $!addr20 as the backward jump distance exceeds what 
; BNH $addr20 can handle.
; CHECK: _br_rel16_bnh_backward_jump_substitute
; CHECK: cmpw ax, bc
; CHECK: skh
; CHECK: br $!.LBB6_1
define void @br_rel16_bnh_backward_jump_substitute(i16 %current, i16 %limit) {
entry:
  br label %do.body

do.body:
  %current.addr.0 = phi i16 [ %current, %entry ], [ %dec, %do.body ]
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %dec = add i16 %current.addr.0, -1
  %cmp.not = icmp ugt i16 %dec, %limit
  br i1 %cmp.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates SKH and BR $!addr20 as the forward jump distance exceeds what 
; BNH $addr20 can handle.
; CHECK: _br_rel16_bnh_forward_jump_substitute
; CHECK: cmpw ax, bc
; CHECK: skh
; CHECK: br $!.LBB7_1
define void @br_rel16_bnh_forward_jump_substitute(i16 %a, i16 %b) {
entry:
  %cmp.not = icmp ugt i16 %a, %b
  br i1 %cmp.not, label %if.end, label %if.then, !prof !1

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  ret void
}

!0 = !{!"branch_weights", i32 1, i32 2000}
!1 = !{!"branch_weights", i32 2000, i32 1}
