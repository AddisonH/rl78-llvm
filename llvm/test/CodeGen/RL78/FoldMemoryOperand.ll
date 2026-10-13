; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@a = internal constant [2 x i16] [i16 1, i16 2], align 2

; Checks MOV_r_i8 is folded into a memory store
; CHECK-LABEL: test_MOV_r_imm
; CHECK-NOT: movw ax, #0
; CHECK: mov [sp+[[SLOT:[0-9]+]]], #0
; CHECK-NOT: movw [sp+[[SLOT]]], ax
define dso_local void @test_MOV_r_imm(ptr nocapture noundef readonly %x, i16 noundef %y) local_unnamed_addr {
entry:
  %smax = tail call i16 @llvm.smax.i16(i16 %y, i16 0)
  br label %for.cond

for.cond:                                        
  %tobool.not = phi i1 [ true, %entry ], [ false, %if.end ]
  %c.0 = phi i16 [ undef, %entry ], [ %0, %if.end ]
  %i.0 = phi i16 [ 0, %entry ], [ %inc, %if.end ]
  %exitcond.not = icmp eq i16 %i.0, %smax
  br i1 %exitcond.not, label %for.end, label %for.body

for.body:                                        
  %arrayidx = getelementptr inbounds i16, ptr %x, i16 %i.0
  %0 = load i16, ptr %arrayidx, align 2
  %cmp1 = icmp eq i16 %0, 0
  br i1 %cmp1, label %for.end, label %if.end

if.end:                                           
  %cmp2.not = icmp sgt i16 %0, %c.0
  %or.cond = or i1 %tobool.not, %cmp2.not
  %inc = add nuw i16 %i.0, 1
  br i1 %or.cond, label %for.cond, label %if.then3

if.then3:                                         
  tail call void @abort() 
  unreachable

for.end:                                          
  ret void
}

declare dso_local void @abort() local_unnamed_addr 

declare i16 @llvm.smax.i16(i16, i16) 

