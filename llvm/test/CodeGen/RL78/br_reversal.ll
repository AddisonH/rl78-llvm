; Test reversal of branch condition, bh -> bnc.
; Ensures this happens when a fallthrough can be created by reversing the condition(reversed_br).
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

declare void @foo(i16)
declare void @bar(i16)

define void @normal_br(i16 %x) {
; CHECK-LABEL: _normal_br:
; CHECK: cmpw
; CHECK-NEXT: xor1 cy
; CHECK-NEXT: bh
; CHECK-NOT: bnc
bb0:
  call void @foo(i16 %x)

  %cond = icmp slt i16 %x, 10
  br i1 %cond, label %bb1, label %bb2

bb1:
  call void @foo(i16 %x)
  ret void

bb2:
  call void @bar(i16 %x)
  ret void
}

define void @reversed_br(i16 %x) {
; CHECK-LABEL: _reversed_br:
; CHECK: cmpw
; CHECK-NEXT: xor1 cy
; CHECK-NEXT: bnc
; CHECK-NOT: bh
bb0:
  call void @foo(i16 %x)

  %cond = icmp slt i16 %x, 10
  br i1 %cond, label %bb1, label %bb2
  
bb2:
  call void @bar(i16 %x)
  ret void

bb1:
  call void @foo(i16 %x)
  ret void
}
