; Verifies that the ExpandPseudoInsts pass correctly creates relative
; conditional branch if true (BT) and branch if false (BF) instructions
; when the operand is a register.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @llvm.rl78.nop()
declare void @padding_function(i64, i64, i64, i64)

; Generates a short relative conditional BT backward branch.
; CHECK: _bt_rel8_backward_jump
; CHECK: bt a.1, $.LBB0_1
define void @bt_rel8_backward_jump(i8 %flags) {
entry:
  br label %do.body

do.body:
  %flags.addr.0 = phi i8 [ %flags, %entry ], [ %0, %do.body ]
  %0 = lshr i8 %flags.addr.0, 1
  %1 = and i8 %flags.addr.0, 2
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates a short relative conditional BT forward branch.
; CHECK: _bt_rel8_forward_jump
; CHECK: bt a.0, $.LBB1_3
define void @bt_rel8_forward_jump(i8 %a, i8 %x) {
entry:
  %conv = zext i8 %a to i16
  %conv1 = zext i8 %x to i16
  %shl = shl nuw i16 1, %conv1
  %and = and i16 %shl, %conv
  %tobool.not = icmp eq i16 %and, 0
  br i1 %tobool.not, label %if.end, label %if.then, !prof !0

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKNC and BR $!addr20 as the backward jump distance exceeds what 
; BT A.X, $addr20 can handle.
; CHECK: _br_rel16_bt_backward_jump_substitute
; CHECK: mov1 cy, a.1
; CHECK: sknc
; CHECK: br $!.LBB2_1
define void @br_rel16_bt_backward_jump_substitute(i8 %flags) {
entry:
  br label %do.body

do.body:
  %flags.addr.0 = phi i8 [ %flags, %entry ], [ %0, %do.body ]
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %0 = lshr i8 %flags.addr.0, 1
  %1 = and i8 %flags.addr.0, 2
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates SKNC and BR $!addr20 as the forward jump distance exceeds what 
; BT A.X, $addr20 can handle.
; CHECK: _br_rel16_bt_forward_jump_substitute
; CHECK: mov1 cy, a.0
; CHECK: sknc
; CHECK: br $!.LBB3_3
define void @br_rel16_bt_forward_jump_substitute(i8 %a, i8 %x) {
entry:
  %conv = zext i8 %a to i16
  %conv1 = zext i8 %x to i16
  %shl = shl nuw i16 1, %conv1
  %and = and i16 %shl, %conv
  %tobool.not = icmp eq i16 %and, 0
  br i1 %tobool.not, label %if.end, label %if.then, !prof !0

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

; Generates a short relative conditional BF backward branch.
; CHECK: _bf_rel8_backward_jump
; CHECK: bf a.1, $.LBB4_1
define void @bf_rel8_backward_jump(i8 %flags) {
entry:
  br label %do.body

do.body:
  %flags.addr.0 = phi i8 [ %flags, %entry ], [ %0, %do.body ]
  %0 = lshr i8 %flags.addr.0, 1
  %1 = and i8 %flags.addr.0, 2
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.body, label %do.end

do.end:
  ret void
}

; Generates a short relative conditional BF forward branch.
; CHECK: _bf_rel8_forward_jump
; CHECK: bf a.0, $.LBB5_4
define void @bf_rel8_forward_jump(i8 %a, i8 %x) {
entry:
  %conv = zext i8 %a to i16
  %conv1 = zext i8 %x to i16
  %shl = shl nuw i16 1, %conv1
  %and = and i16 %shl, %conv
  %tobool.not = icmp eq i16 %and, 0
  br i1 %tobool.not, label %if.end, label %if.then

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKC and BR $!addr20 as the backward jump distance exceeds what 
; BF A.X, $addr20 can handle.
; CHECK: _br_rel16_bf_backward_jump_substitute
; CHECK: mov1 cy, a.1
; CHECK: skc
; CHECK: br $!.LBB6_1
define void @br_rel16_bf_backward_jump_substitute(i8 %flags) {
entry:
  br label %do.body

do.body:
  %flags.addr.0 = phi i8 [ %flags, %entry ], [ %0, %do.body ]
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %0 = lshr i8 %flags.addr.0, 1
  %1 = and i8 %flags.addr.0, 2
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.body, label %do.end

do.end:
  ret void
}

; Generates SKC and BR $!addr20 as the forward jump distance exceeds what 
; BF A.X, $addr20 can handle.
; CHECK: _br_rel16_bf_forward_jump_substitute
; CHECK: mov1 cy, a.0
; CHECK: skc
; CHECK: br $!.LBB7_4
define void @br_rel16_bf_forward_jump_substitute(i8 %a, i8 %x) {
entry:
  %conv = zext i8 %a to i16
  %conv1 = zext i8 %x to i16
  %shl = shl nuw i16 1, %conv1
  %and = and i16 %shl, %conv
  %tobool.not = icmp eq i16 %and, 0
  br i1 %tobool.not, label %if.end, label %if.then

if.then:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  br label %if.end

if.end:
  call void @llvm.rl78.nop()
  ret void
}

!0 = !{!"branch_weights", i32 2000, i32 1}
