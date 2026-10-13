; RUN: llc -verify-machineinstrs -mtriple=rl78 < %s | FileCheck %s

; CMPW AX, #0 is 3 bytes. OR A, X sets Z the same way in 2 when A is not
; needed afterwards; CLRW BC + CMPW AX, BC is 2 bytes when AX is still needed
; and BC is free, at the cost of an instruction (size levels only).

declare void @use(i16)

define i16 @value_dead(i16 %x, i16 %y) {
; CHECK-LABEL: _value_dead:
; CHECK:       or a, x
; CHECK-NOT:   cmpw
entry:
  %c = icmp eq i16 %x, 0
  br i1 %c, label %a, label %b
a:
  ret i16 %y
b:
  ret i16 7
}

define void @value_live_size(i16 %x) optsize {
; CHECK-LABEL: _value_live_size:
; CHECK:       clrw bc
; CHECK-NEXT:  cmpw ax, bc
entry:
  %c = icmp eq i16 %x, 0
  br i1 %c, label %done, label %call
call:
  tail call void @use(i16 %x)
  br label %done
done:
  ret void
}

define void @value_live_speed(i16 %x) {
; CHECK-LABEL: _value_live_speed:
; CHECK:       cmpw ax, #0
entry:
  %c = icmp eq i16 %x, 0
  br i1 %c, label %done, label %call
call:
  tail call void @use(i16 %x)
  br label %done
done:
  ret void
}
