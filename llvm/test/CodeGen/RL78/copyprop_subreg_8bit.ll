; MachineCopyPropagation runs with UseCopyInstr, so RL78InstrInfo::isCopyInstrImpl
; decides what it treats as a copy. The 8-bit MOV_A_r/MOV_r_A must stay out of
; that list: their register classes span A and X, which are the two halves of AX,
; and the pass then reasons across the pair/half boundary and deletes moves that
; are not redundant.
;
; Reduced from CoreMark's core_state_transition, where including them produced
; crclist 0x8c27 instead of 0xe714 and crcstate 0xcebb instead of 0x8e3a.
;
; Here "mov a, x" is the first instruction of a loop header and CLRW AX at the
; bottom of the loop kills both halves, so on the second iteration A is dead
; before it. Deleting the move is unsound, not an optimisation.
;
; RUN: llc -O2 -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; CHECK-LABEL: _loop_carried_half_copy:
; CHECK: .LBB0_1:
; CHECK-NEXT: mov a, x
; CHECK-NEXT: mov [sp+0], a

define i16 @loop_carried_half_copy() {
  br label %1

1:
  %2 = phi i8 [ 1, %0 ], [ 0, %5 ]
  %3 = call fastcc i8 null()
  %cond = icmp eq i8 %2, 0
  br i1 %cond, label %4, label %5

4:
  br label %5

5:
  %6 = phi i16 [ 1, %4 ], [ 0, %1 ]
  br label %1
}
