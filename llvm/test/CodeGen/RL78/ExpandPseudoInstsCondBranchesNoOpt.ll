; Verifies correct ExpandPseudoInsts pass behavior when there is a branch 
; pseudo-instruction preceding the terminating branch pseudo-instruction in 
; the same basic block.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8
-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare void @llvm.rl78.nop()
declare void @padding_function(i64, i64, i64, i64)

; Generates a short conditional BZ branch instruction followed by a
; short unconditional branch instruction.
; CHECK: _bz_rel8_followed_by_br_rel8
; CHECK: bz $.LBB0_2
; CHECK: br $.LBB0_1
define void @bz_rel8_followed_by_br_rel8(i16 %condition) noinline optnone {
entry:
  %tobool = icmp ne i16 %condition, 0
  br i1 %tobool, label %if.then, label %if.else

if.then:
  call void @llvm.rl78.nop()
  br label %if.end

if.else:
  call void @llvm.rl78.nop()
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}

; Generates SKNZ and BR $!addr20 (due to the jump distance exceeding what
; BZ $addr20 can handle) followed by a short unconditional branch instruction.
; CHECK: _br_rel16_bz_jump_substitute_followed_by_br_rel8
; CHECK: sknz
; CHECK: br $!.LBB1_2
; CHECK: br $.LBB1_1
define void @br_rel16_bz_jump_substitute_followed_by_br_rel8(i16 %cond) noinline optnone {
entry:
  %tobool = icmp ne i16 %cond, 0
  br i1 %tobool, label %if.then, label %if.else

if.then:
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  call void @padding_function(i64 0, i64 0, i64 0, i64 0)
  br label %if.end

if.else:
  call void @llvm.rl78.nop()
  br label %if.end

if.end:
  ret void
}
