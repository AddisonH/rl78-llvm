; Test for replacing the BT saddr.bit + CLR1 saddr.bit with a BTCLR.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

@x = global i16 0
@y = global i8 0 #0

define void @faux() {
  ret void
}

define void @test()  {
entry:
  %0 = load volatile i8, ptr @y
  %1 = and i8 %0, 1
  %cmp = icmp eq i8 %1, 0
  br i1 %cmp, label %if.then, label %if.end

if.then:
  %2 = load i16, ptr @x, align 2
  %inc.i = add nsw i16 %2, 1
  store i16 %inc.i, ptr @x, align 2
  br label %if.end

if.end:
  %3 = load volatile i8, ptr @y
  %4 = and i8 %3, -2
  store volatile i8 %4, ptr @y
  ret void
}

attributes #0 = { "saddr" }


; CHECK: btclr _y.0, $
; CHECK:	.section	.sbss
; CHECK-NEXT:	.globl	_y
; CHECK-NOT: mov a, _y
; CHECK-NOT: bt a.0
; CHECK-NOT: clr1 _y.0
