; Verifies that the ExpandPseudoInsts pass correctly creates relative
; conditional branch if true (BT) and branch if false (BF) instructions
; when the operand is a [HL].
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @llvm.rl78.nop()
declare void @padding_function(i64, i64, i64, i64)

; Generates a short relative conditional BT backward branch with the [HL] operand.
; CHECK: _bt_rel8_backward_jump_hl
; CHECK: bt [hl].0, $.LBB0_1
define void @bt_rel8_backward_jump_hl(ptr %flags) {
entry:
  br label %do.body

do.body:
  %flags.addr.0 = phi ptr [ %flags, %entry ], [ %incdec.ptr, %do.body ]
  %incdec.ptr = getelementptr inbounds i8, ptr %flags.addr.0, i16 1
  %0 = load volatile i8, ptr %incdec.ptr, align 1
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates a short relative conditional BT forward branch with the [HL] operand.
; CHECK: _bt_rel8_forward_jump_hl
; CHECK: bt [hl].0, $.LBB1_1
define void @bt_rel8_forward_jump_hl(ptr %a) {
entry:
  %0 = load volatile i8, ptr %a, align 1
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
; BT [HL].X, $addr20 can handle.
; CHECK: _br_rel16_bt_backward_jump_substitute_hl
; CHECK: mov1 cy, [hl].0
; CHECK: sknc
; CHECK: br $!.LBB2_1
define void @br_rel16_bt_backward_jump_substitute_hl(ptr %flags) {
entry:
  br label %do.body

do.body:
  %flags.addr.0 = phi ptr [ %flags, %entry ], [ %incdec.ptr, %do.body ]
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %incdec.ptr = getelementptr inbounds i8, ptr %flags.addr.0, i16 1
  %0 = load volatile i8, ptr %incdec.ptr, align 1
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.end, label %do.body

do.end:
  ret void
}

; Generates SKNC and BR $!addr20 as the forward jump distance exceeds what 
; BT [HL].X, $addr20 can handle.
; CHECK: _br_rel16_bt_forward_jump_substitute_hl
; CHECK: mov1 cy, [hl].0
; CHECK: sknc
; CHECK: br $!.LBB3_1
define void @br_rel16_bt_forward_jump_substitute_hl(ptr %a) {
entry:
  %0 = load volatile i8, ptr %a, align 1
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

; Generates a short relative conditional BF backward branch with the [HL] operand.
; CHECK: _bf_rel8_backward_jump_hl
; CHECK: bf [hl].0, $.LBB4_1
define void @bf_rel8_backward_jump_hl(ptr %flags) {
entry:
  br label %do.body

do.body:
  %flags.addr.0 = phi ptr [ %flags, %entry ], [ %incdec.ptr, %do.body ]
  %incdec.ptr = getelementptr inbounds i8, ptr %flags.addr.0, i16 1
  %0 = load volatile i8, ptr %incdec.ptr, align 1
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.body, label %do.end

do.end:
  ret void
}

; Generates a short relative conditional BF forward branch with the [HL] operand.
; CHECK: _bf_rel8_forward_jump_hl
; CHECK: bf [hl].0, $.LBB5_2
define void @bf_rel8_forward_jump_hl(ptr %a) {
entry:
  %0 = load volatile i8, ptr %a, align 1
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
; BF [HL].X, $addr20 can handle.
; CHECK: _br_rel16_bf_backward_jump_substitute_hl
; CHECK: mov1 cy, [hl].0
; CHECK: skc
; CHECK: br $!.LBB6_1
define void @br_rel16_bf_backward_jump_substitute_hl(ptr %flags) {
entry:
  br label %do.body

do.body:
  %flags.addr.0 = phi ptr [ %flags, %entry ], [ %incdec.ptr, %do.body ]
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %incdec.ptr = getelementptr inbounds i8, ptr %flags.addr.0, i16 1
  %0 = load volatile i8, ptr %incdec.ptr, align 1
  %1 = and i8 %0, 1
  %tobool.not = icmp eq i8 %1, 0
  br i1 %tobool.not, label %do.body, label %do.end

do.end:
  ret void
}

; Generates SKC and BR $!addr20 as the forward jump distance exceeds what 
; BF [HL].X, $addr20 can handle.
; CHECK: _br_rel16_bf_forward_jump_substitute_hl
; CHECK: mov1 cy, [hl].0
; CHECK: skc
; CHECK: br $!.LBB7_2
define void @br_rel16_bf_forward_jump_substitute_hl(ptr %a) {
entry:
  %0 = load volatile i8, ptr %a, align 1
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
