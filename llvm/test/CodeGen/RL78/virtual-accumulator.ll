; AX/A operands fixed by the custom inserters are carried in virtual registers
; of the single-register classes (RL78AXRP, RL78AReg),
; and the allocator learns which operands must be AX/A from
; RL78AccumulatorOperands.def.
; RUN: llc -O2 -mcpu=RL78_S3 -stop-before=register-coalescer < %s | FileCheck %s --check-prefix=MIR
; RUN: llc -O2 -mcpu=RL78_S3 < %s | FileCheck %s --check-prefix=ASM
; Everything allocates also when the coalescer may keep values in AX and the
; machine scheduler reorders around them.
; RUN: llc -O2 -mcpu=RL78_S3 -rl78-acc-coalesce -rl78-acc-misched -o /dev/null < %s
target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; The running sum and the pointers are added in AX; each value is in AX only
; from the copy in to the copy out.
; MIR-LABEL: name: dot
; MIR: :rl78axrp = ADDW_AX_mHLi
; MIR: :rl78axrp = ADDW_rp_imm
; MIR: :rl78axrp = ADDW_AX_mHLi
define dso_local i16 @dot(ptr nofree noundef readonly captures(none) %a, ptr nofree noundef readonly captures(none) %b, i16 noundef %n) local_unnamed_addr {
entry:
  %cmp7 = icmp sgt i16 %n, 0
  br i1 %cmp7, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.body, %entry
  %s.0.lcssa = phi i16 [ 0, %entry ], [ %add2, %for.body ]
  ret i16 %s.0.lcssa

for.body:                                         ; preds = %entry, %for.body
  %i.09 = phi i16 [ %inc, %for.body ], [ 0, %entry ]
  %s.08 = phi i16 [ %add2, %for.body ], [ 0, %entry ]
  %arrayidx = getelementptr inbounds nuw [2 x i8], ptr %a, i16 %i.09
  %0 = load i16, ptr %arrayidx, align 2
  %arrayidx1 = getelementptr inbounds nuw [2 x i8], ptr %b, i16 %i.09
  %1 = load i16, ptr %arrayidx1, align 2
  %add = add i16 %0, %s.08
  %add2 = add i16 %add, %1
  %inc = add nuw nsw i16 %i.09, 1
  %exitcond.not = icmp eq i16 %inc, %n
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; CMP0 encodes only X, A, C and B: the byte compared stays where CMP0 can
; read it after the allocator has split it out of A.
; ASM-LABEL: cls:
; ASM-NOT: cmp0 {{[dehl]$}}
; ASM: ret
define dso_local range(i16 0, 5) i16 @cls(ptr nofree noundef readonly captures(none) %p) local_unnamed_addr {
entry:
  %0 = load i8, ptr %p, align 1
  switch i8 %0, label %if.end11 [
    i8 0, label %cleanup
    i8 44, label %if.then5
    i8 46, label %if.then10
  ]

if.then5:                                         ; preds = %entry
  br label %cleanup

if.then10:                                        ; preds = %entry
  br label %cleanup

if.end11:                                         ; preds = %entry
  %sub = add i8 %0, -48
  %cmp15 = icmp ult i8 %sub, 10
  %cond = select i1 %cmp15, i16 3, i16 4
  br label %cleanup

cleanup:                                          ; preds = %entry, %if.end11, %if.then10, %if.then5
  %retval.0 = phi i16 [ %cond, %if.end11 ], [ 1, %if.then5 ], [ 2, %if.then10 ], [ 0, %entry ]
  ret i16 %retval.0
}

; Two loops over a list: loaded pointers go through AX into HL/BC/DE.
; ASM-LABEL: find:
; ASM: ret
define dso_local ptr @find(ptr nofree noundef readonly captures(address_is_null, ret: address, provenance) %list, i16 noundef %key, i16 noundef %idx) local_unnamed_addr {
entry:
  %cmp = icmp sgt i16 %idx, -1
  br i1 %cmp, label %while.cond.preheader, label %while.cond2.preheader

while.cond2.preheader:                            ; preds = %entry
  %tobool3.not22 = icmp eq ptr %list, null
  br i1 %tobool3.not22, label %return, label %land.rhs4

while.cond.preheader:                             ; preds = %entry
  %tobool.not25 = icmp eq ptr %list, null
  br i1 %tobool.not25, label %return, label %land.rhs

land.rhs:                                         ; preds = %while.cond.preheader, %while.body
  %list.addr.026 = phi ptr [ %2, %while.body ], [ %list, %while.cond.preheader ]
  %info = getelementptr inbounds nuw i8, ptr %list.addr.026, i16 2
  %0 = load ptr, ptr %info, align 2
  %arrayidx = getelementptr inbounds nuw i8, ptr %0, i16 2
  %1 = load i16, ptr %arrayidx, align 2
  %cmp1.not = icmp eq i16 %1, %idx
  br i1 %cmp1.not, label %return, label %while.body

while.body:                                       ; preds = %land.rhs
  %2 = load ptr, ptr %list.addr.026, align 2
  %tobool.not = icmp eq ptr %2, null
  br i1 %tobool.not, label %return, label %land.rhs

land.rhs4:                                        ; preds = %while.cond2.preheader, %while.body9
  %list.addr.123 = phi ptr [ %5, %while.body9 ], [ %list, %while.cond2.preheader ]
  %info5 = getelementptr inbounds nuw i8, ptr %list.addr.123, i16 2
  %3 = load ptr, ptr %info5, align 2
  %4 = load i16, ptr %3, align 2
  %and = and i16 %4, 255
  %cmp7.not = icmp eq i16 %and, %key
  br i1 %cmp7.not, label %return, label %while.body9

while.body9:                                      ; preds = %land.rhs4
  %5 = load ptr, ptr %list.addr.123, align 2
  %tobool3.not = icmp eq ptr %5, null
  br i1 %tobool3.not, label %return, label %land.rhs4

return:                                           ; preds = %while.body9, %land.rhs4, %while.body, %land.rhs, %while.cond2.preheader, %while.cond.preheader
  %retval.0 = phi ptr [ null, %while.cond2.preheader ], [ null, %while.cond.preheader ], [ %list.addr.026, %land.rhs ], [ null, %while.body ], [ %list.addr.123, %land.rhs4 ], [ null, %while.body9 ]
  ret ptr %retval.0
}
