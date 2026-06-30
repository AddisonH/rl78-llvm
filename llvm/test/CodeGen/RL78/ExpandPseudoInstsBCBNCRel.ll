; Verifies that the ExpandPseudoInsts pass correctly creates relative
; conditional branch if carry (BC) and branch if not carry (BNC)
; instructions.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @llvm.rl78.nop() 
declare void @padding_function(i64, i64, i64, i64)

; Generates a short relative conditional BC backward branch.
; CHECK: _bc_rel8_backward_jump
; CHECK: cmpw ax, bc
; CHECK: bc $.LBB0_1
define void @bc_rel8_backward_jump(i16 %current, i16 %limit) {
entry:
  br label %do.body

do.body:
  %current.addr.0 = phi i16 [ %current, %entry ], [ %inc, %do.body ]
  call void @llvm.rl78.nop()
  %inc = add i16 %current.addr.0, 1
  %cmp = icmp ult i16 %inc, %limit
  br i1 %cmp, label %do.body, label %do.end

do.end:
  ret void
}

; Generates a short relative conditional BC forward branch.
; CHECK: _bc_rel8_forward_jump
; CHECK: cmpw ax, bc
; CHECK: bc $.LBB1_2
define void @bc_rel8_forward_jump(i16 %a, i16 %b) {
entry:
  %cmp.not = icmp ult i16 %a, %b
  br i1 %cmp.not, label %if.end, label %if.then

if.then:
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKNC and BR $!addr20 as the backward jump distance exceeds what 
; BC $addr20 can handle.
; CHECK: _br_rel16_bc_backward_jump_substitute
; CHECK: cmpw ax, bc
; CHECK: sknc
; CHECK: br $!.LBB2_1
define void @br_rel16_bc_backward_jump_substitute(i16 %current, i16 %limit) {
entry:
  br label %do.body

do.body:
  %current.addr.0 = phi i16 [ %current, %entry ], [ %inc, %do.body ]
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %inc = add i16 %current.addr.0, 1
  %cmp = icmp ult i16 %inc, %limit
  br i1 %cmp, label %do.body, label %do.end

do.end:
  ret void
}

; Generates SKNC and BR $!addr20 as the forward jump distance exceeds what 
; BC $addr20 can handle.
; CHECK: _br_rel16_bc_forward_jump_substitute
; CHECK: cmpw ax, bc
; CHECK: sknc
; CHECK: br $!.LBB3_2
define void @br_rel16_bc_forward_jump_substitute(i16 %a, i16 %b) {
entry:
  %cmp.not = icmp ult i16 %a, %b
  br i1 %cmp.not, label %if.end, label %if.then

if.then:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  br label %if.end

if.end:
  ret void
}

; Generates a short relative conditional BNC backward branch.
; CHECK: _bnc_rel8_backward_jump
; CHECK: decw ax
; CHECK: cmpw ax, bc
; CHECK: bnc $.LBB4_1
define void @bnc_rel8_backward_jump(i16 %current, i16 %limit) {
entry:
  br label %do.body

do.body:
  %current.addr.0 = phi i16 [ %current, %entry ], [ %dec, %do.body ]
  call void @llvm.rl78.nop()
  %dec = add i16 %current.addr.0, -1
  %cmp.not = icmp ult i16 %dec, %limit
  br i1 %cmp.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates a short relative conditional BNC forward branch.
; CHECK: _bnc_rel8_forward_jump
; CHECK: cmpw ax, bc
; CHECK: bnc $.LBB5_2
define void @bnc_rel8_forward_jump(i16 %a, i16 %b)  {
entry:
  %cmp = icmp ult i16 %a, %b
  br i1 %cmp, label %if.then, label %if.end

if.then:
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKC and BR $!addr20 as the backward jump distance exceeds what 
; BNC $addr20 can handle.
; CHECK: _br_rel16_bnc_backward_jump_substitute
; CHECK: cmpw ax, bc
; CHECK: skc
; CHECK: br $!.LBB6_1
define void @br_rel16_bnc_backward_jump_substitute(i16 %current, i16 %limit) {
entry:
  br label %do.body

do.body:
  %current.addr.0 = phi i16 [ %current, %entry ], [ %dec, %do.body ]
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %dec = add i16 %current.addr.0, -1
  %cmp.not = icmp ult i16 %dec, %limit
  br i1 %cmp.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates SKC and BR $!addr20 as the forward jump distance exceeds what 
; BNC $addr20 can handle.
; CHECK: _br_rel16_bnc_forward_jump_substitute
; CHECK: cmpw ax, bc
; CHECK: skc
; CHECK: br $!.LBB7_2
define void @br_rel16_bnc_forward_jump_substitute(i16 %a, i16 %b) {
entry:
  %cmp = icmp ult i16 %a, %b
  br i1 %cmp, label %if.then, label %if.end

if.then:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  br label %if.end

if.end:
  ret void
}
