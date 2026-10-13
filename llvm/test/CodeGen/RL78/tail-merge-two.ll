; Two instructions in common at the end of two blocks are merged: the branch
; to the common tail takes two bytes (RL78InstrInfo::getTailMergeSize).
; RUN: llc -verify-machineinstrs -mtriple=rl78 -O2 < %s | FileCheck %s
; RUN: llc -verify-machineinstrs -mtriple=rl78 -O2 -tail-merge-size=3 < %s | FileCheck %s --check-prefix=THREE

@a = global i8 0
@b = global i8 0

define void @f(i16 %x) optsize {
; CHECK-LABEL: _f:
; CHECK: clrb !LOWW(_b)
; CHECK-NOT: clrb !LOWW(_b)
; THREE-LABEL: _f:
; THREE: clrb !LOWW(_b)
; THREE: clrb !LOWW(_b)
entry:
  %t = icmp eq i16 %x, 0
  br i1 %t, label %l, label %r

l:
  store volatile i8 1, ptr @a
  store volatile i8 0, ptr @b
  ret void

r:
  store volatile i8 2, ptr @a
  store volatile i8 0, ptr @b
  ret void
}
