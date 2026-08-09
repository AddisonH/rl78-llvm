; Redo 32-bit arithmetic in 16 bits when only the low half is demanded.
;
; This is CoreMark's matrix_add_const index computation. The i32 multiply feeds
; an i32 add whose only use is a trunc to i16, so DemandedBits reports 0xffff
; for the multiply. Without narrowing it becomes an out-of-line call to
; __COM_lmul; with it, a single MULHU.
;
; InstCombine and AggressiveInstCombine both decline this case because the
; expression DAG reaches a loop PHI, which TruncInstCombine does not narrow
; through -- hence the dedicated pass.
;
; RUN: llc -O2 -mtriple=rl78 -rl78-narrow-demanded-ops=false < %s \
; RUN:   | FileCheck %s --check-prefix=NONARROW
; RUN: llc -O2 -mtriple=rl78 -rl78-narrow-demanded-ops=true < %s \
; RUN:   | FileCheck %s --check-prefix=NARROW

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; NONARROW-LABEL: _matrix_add_const:
; NONARROW: call {{.*}}__COM_lmul
; NONARROW-NOT: mulhu

; NARROW-LABEL: _matrix_add_const:
; NARROW-NOT: __COM_lmul
; NARROW: mulhu

define dso_local void @matrix_add_const(i32 noundef %n, ptr nocapture noundef %a, i16 noundef %val) local_unnamed_addr {
entry:
  %isz = icmp eq i32 %n, 0
  br i1 %isz, label %done, label %outer

outer:
  %i = phi i32 [ %inext, %latch ], [ 0, %entry ]
  %rowbase = mul i32 %i, %n
  br label %inner

inner:
  %j = phi i32 [ 0, %outer ], [ %jnext, %inner ]
  %idx32 = add i32 %j, %rowbase
  %idx = trunc i32 %idx32 to i16
  %p = getelementptr inbounds i16, ptr %a, i16 %idx
  %ld = load i16, ptr %p, align 2
  %sum = add nsw i16 %ld, %val
  store i16 %sum, ptr %p, align 2
  %jnext = add nuw i32 %j, 1
  %jcmp = icmp ult i32 %jnext, %n
  br i1 %jcmp, label %inner, label %latch

latch:
  %inext = add nuw i32 %i, 1
  %icmp = icmp ult i32 %inext, %n
  br i1 %icmp, label %outer, label %done

done:
  ret void
}
