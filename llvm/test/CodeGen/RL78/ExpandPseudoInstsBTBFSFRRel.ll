; Verifies that the ExpandPseudoInsts pass correctly creates relative
; conditional branch if true (BT) and branch if false (BF) instructions
; when the operand is a special function register (SFR).
; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @llvm.rl78.nop()
declare void @padding_function(i64, i64, i64, i64)

; Generates a short relative conditional BT backward branch with a SFR operand.
; CHECK: _bt_rel8_backward_jump_sfr
; CHECK: bt 0xfff00.0, $.LBB0_1
define void @bt_rel8_backward_jump_sfr() {
entry:
  br label %do.body

do.body:
  call void @llvm.rl78.nop()
  %0 = load volatile i8, ptr inttoptr (i16 -256 to ptr), align 256
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates a short relative conditional BT forward branch with a SFR operand.
; CHECK: _bt_rel8_forward_jump_sfr
; CHECK: bt 0xfff00.0, $.LBB1_1
define void @bt_rel8_forward_jump_sfr() {
entry:
  %0 = load volatile i8, ptr inttoptr (i16 -256 to ptr), align 256
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %if.end, label %if.then, !prof !0

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKNC and BR $!addr20 as the backward jump distance exceeds what 
; BT sfr.0, $addr20 can handle.
; CHECK: _br_rel16_bt_backward_jump_substitute_sfr
; CHECK: mov1 cy, 0xfff00.0 
; CHECK: sknc
; CHECK: br $!.LBB2_1
define void @br_rel16_bt_backward_jump_substitute_sfr() {
entry:
  br label %do.body

do.body:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %0 = load volatile i8, ptr inttoptr (i16 -256 to ptr), align 256
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates SKNC and BR $!addr20 as the forward jump distance exceeds what 
; BT sfr.0, $addr20 can handle.
; CHECK: _br_rel16_bt_forward_jump_substitute_sfr
; CHECK: mov1 cy, 0xfff00.0 
; CHECK: sknc
; CHECK: br $!.LBB3_1
define void @br_rel16_bt_forward_jump_substitute_sfr() {
entry:
  %0 = load volatile i8, ptr inttoptr (i16 -256 to ptr), align 256
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
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

; Generates a short relative conditional BF backward branch with a SFR operand.
; CHECK: _bf_rel8_backward_jump_sfr
; CHECK: bf 0xfff00.0, $.LBB4_1
define void @bf_rel8_backward_jump_sfr() {
entry:
  br label %do.body

do.body:
  call void @llvm.rl78.nop()
  %0 = load volatile i8, ptr inttoptr (i16 -256 to ptr), align 256
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.body, label %do.end

do.end:
  ret void
}

; Generates a short relative conditional BF forward branch with a SFR operand.
; CHECK: _bf_rel8_forward_jump_sfr
; CHECK: bf 0xfff00.0, $.LBB5_2
define void @bf_rel8_forward_jump_sfr() {
entry:
  %0 = load volatile i8, ptr inttoptr (i16 -256 to ptr), align 256
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %if.end, label %if.then

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKC and BR $!addr20 as the backward jump distance exceeds what 
; BF sfr.0, $addr20 can handle.
; CHECK: _br_rel16_bf_backward_jump_substitute_sfr
; CHECK: mov1 cy, 0xfff00.0 
; CHECK: skc
; CHECK: br $!.LBB6_1
define void @br_rel16_bf_backward_jump_substitute_sfr() {
entry:
  br label %do.body

do.body:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %0 = load volatile i8, ptr inttoptr (i16 -256 to ptr), align 256
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.body, label %do.end

do.end:
  ret void
}

; Generates SKC and BR $!addr20 as the forward jump distance exceeds what 
; BF sfr.0, $addr20 can handle.
; CHECK: _br_rel16_bf_forward_jump_substitute_sfr
; CHECK: mov1 cy, 0xfff00.0 
; CHECK: skc
; CHECK: br $!.LBB7_2
define void @br_rel16_bf_forward_jump_substitute_sfr() {
entry:
  %0 = load volatile i8, ptr inttoptr (i16 -256 to ptr), align 256
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %if.end, label %if.then

if.then:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  br label %if.end

if.end:
  ret void
}

!0 = !{!"branch_weights", i32 2000, i32 1}
