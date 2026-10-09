; A value that can only be in AX has a higher spill weight
; (RL78RegisterInfo::getSpillWeightScaleFactor), so it evicts a value that
; was only hinted to AX instead of being spilled itself. Four halves of two
; longs fit AX, BC, DE and HL.
; RUN: llc -mtriple=rl78 -O2 < %s | FileCheck %s

@a = global [4 x i32] zeroinitializer
@b = global [4 x i32] zeroinitializer
@x = global i16 0

; CHECK-LABEL: _f:
; CHECK-NOT: [sp
; CHECK: cmpw ax,
; CHECK-NOT: [sp
; CHECK: ret
define void @f() {
  %a1 = load i32, ptr getelementptr (i8, ptr @a, i16 4)
  %b2 = load i32, ptr getelementptr (i8, ptr @b, i16 8)
  %c = icmp eq i32 %a1, %b2
  br i1 %c, label %t, label %e
t:
  %x = load i16, ptr @x
  %x1 = add i16 %x, 3
  store i16 %x1, ptr @x
  br label %e
e:
  ret void
}
