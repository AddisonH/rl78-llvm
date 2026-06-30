; Verifies that the ExpandPseudoInsts pass correctly creates relative
; conditional branch if zero (BZ) and branch if not zero (BNZ)
; instructions.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @llvm.rl78.nop()
declare void @padding_function(i64, i64, i64, i64)

; Generates a short relative conditional BZ backward branch.
; CHECK: _bz_rel8_backward_jump
; CHECK: cmpw ax, #0
; CHECK: bz $.LBB0_1
define void @bz_rel8_backward_jump(i16 %flag) {
entry:
  %cmp = icmp eq i16 %flag, 0
  br label %do.body

do.body:
  call void @llvm.rl78.nop()
  br i1 %cmp, label %do.body, label %do.end

do.end:
  ret void
}

; Generates a short relative conditional BZ forward branch.
; CHECK: _bz_rel8_forward_jump
; CHECK: cmpw ax, #-1
; CHECK: bz $.LBB1_1
define void @bz_rel8_forward_jump(i16 %exit_code) {
entry:
  %cmp = icmp eq i16 %exit_code, -1
  br i1 %cmp, label %if.then, label %if.end

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  call void @llvm.rl78.nop()
  ret void
}

; Generates SKNZ and BR $!addr20 as the backward jump distance exceeds what 
; BZ $addr20 can handle.
; CHECK: _br_rel16_bz_backward_jump_substitute
; CHECK: cmpw ax, #0
; CHECK: sknz
; CHECK: br $!.LBB2_1
define void @br_rel16_bz_backward_jump_substitute(i16 %flag) {
entry:
  %cmp = icmp eq i16 %flag, 0
  br label %do.body

do.body:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  br i1 %cmp, label %do.body, label %do.end

do.end:
  ret void
}

; Generates SKNZ and BR $!addr20 as the forward jump distance exceeds what
; CHECK: _br_rel16_bz_forward_jump_substitute 
; BZ $addr20 can handle.
; CHECK: cmpw ax, #-1
; CHECK: sknz
; CHECK: br $!.LBB3_1
define void @br_rel16_bz_forward_jump_substitute(i16 %exit_code) {
entry:
  %cmp = icmp eq i16 %exit_code, -1
  br i1 %cmp, label %if.then, label %if.end, !prof !1

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

; Generates a short relative conditional BNZ backward branch.
; CHECK: _bnz_rel8_backward_jump
; CHECK: decw ax
; CHECK: cmpw ax, #0
; CHECK: bnz $.LBB4_1
define void @bnz_rel8_backward_jump(i16 %counter) {
entry:
  %cmp2 = icmp sgt i16 %counter, 0
  br i1 %cmp2, label %for.body, label %for.cond.cleanup

for.cond.cleanup:
  ret void

for.body:
  %i.03 = phi i16 [ %inc, %for.body ], [ 0, %entry ]
  call void @llvm.rl78.nop()
  %inc = add i16 %i.03, 1
  %exitcond.not = icmp eq i16 %inc, %counter
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Generates a short relative conditional BNZ forward branch.
; CHECK: _bnz_rel8_forward_jump
; CHECK: cmpw ax, #0
; CHECK: bnz $.LBB5_1
define void @bnz_rel8_forward_jump(i16 %exit_code) {
entry:
  %cmp.not = icmp eq i16 %exit_code, 0
  br i1 %cmp.not, label %if.end, label %if.then, !prof !0  

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  call void @llvm.rl78.nop()
  ret void
}

; Generates SKZ and BR $!addr20 as the backward jump distance exceeds what 
; BNZ $addr20 can handle.
; CHECK: _br_rel16_bnz_backward_jump_substitute
; CHECK: cmpw ax, #0
; CHECK: skz 
; CHECK: br $!.LBB6_1
define void @br_rel16_bnz_backward_jump_substitute(i16 %counter) {
entry:
  %cmp2 = icmp sgt i16 %counter, 0
  br i1 %cmp2, label %for.body, label %for.cond.cleanup

for.cond.cleanup:
  ret void

for.body:
  %i.03 = phi i16 [ %inc, %for.body ], [ 0, %entry ]
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  %inc = add i16 %i.03, 1
  %exitcond.not = icmp eq i16 %inc, %counter
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; Generates SKZ and BR $!addr20 as the forward jump distance exceeds what 
; BNZ $addr20 can handle.
; CHECK: _br_rel16_bnz_forward_jump_substitute
; CHECK: cmpw ax, #0
; CHECK: skz
; CHECK: br $!.LBB7_1
define void @br_rel16_bnz_forward_jump_substitute(i16 %exit_code) {
entry:
  %cmp.not = icmp eq i16 %exit_code, 0
  br i1 %cmp.not, label %if.end, label %if.then, !prof !0

if.then:
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  ret void
}

!0 = !{!"branch_weights", i32 2000, i32 1}
!1 = !{!"branch_weights", i32 1, i32 2000}
