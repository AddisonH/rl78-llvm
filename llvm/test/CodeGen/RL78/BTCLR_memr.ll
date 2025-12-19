; Test for replacing the BT [HL].bit + CLR1 [HL].bit with a BTCLR.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s
@a = global ptr inttoptr (i16 4660 to ptr), align 2

define void @foo() {
  ret void
}

define void @test() {
entry:
  %0 = load ptr, ptr @a, align 2
  %1 = load volatile i8, ptr %0, align 1
  %2 = and i8 %1, 4
  %cmp = icmp eq i8 %2, 0
  br i1 %cmp, label %if.then, label %if.end

if.then:
  call void @foo()
  %.pre = load ptr, ptr @a, align 2
  br label %if.end

if.end:
  %3 = phi ptr [ %.pre, %if.then ], [ %0, %entry ]
  %4 = load volatile i8, ptr %3, align 1
  %5 = and i8 %4, -5
  store volatile i8 %5, ptr %3, align 1
  ret void
}

; CHECK: btclr [hl].2, $
; CHECK-NOT: bt [hl].2
; CHECK-NOT: clr1 [hl].2
