; Test for replacing the BT sfr.bit + CLR1 sfr.bit with a BTCLR.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

define void @faux() {
  ret void
}

define void @test() {
entry:
  %bf.load = load volatile i8, ptr inttoptr (i16 -1 to ptr), align 2
  %0 = and i8 %bf.load, 2
  %cmp = icmp eq i8 %0, 0
  br i1 %cmp, label %if.then, label %if.end

if.then:
  call void @faux()
  br label %if.end

if.end:
  call void @llvm.rl78.clr1.p0(ptr nonnull inttoptr (i16 -1 to ptr), i8 1)
  ret void
}

declare void @llvm.rl78.clr1.p0(ptr, i8)

; CHECK: btclr 0xfffff.1, $
; CHECK-NOT: bt 0xfffff.1
; CHECK-NOT: clr1 0xfffff.1
