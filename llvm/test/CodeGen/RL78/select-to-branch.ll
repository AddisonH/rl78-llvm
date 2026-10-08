; RUN: opt -S -mtriple=rl78 -passes='require<profile-summary>,function(codegenprepare)' < %s | FileCheck %s

; RL78 has no conditional move. CodeGenPrepare turns a group of selects on one
; condition, or an i32 select, into one branch; it leaves single i8/i16 and
; i1 selects to instruction selection.

; CHECK-LABEL: @group(
; CHECK:       br i1
; CHECK:       select.end:
; CHECK-NEXT:  phi i32
; CHECK-NEXT:  phi i16
define i16 @group(i32 %t, i32 %clip, i16 %r, i16 %inc, ptr %p) {
  %c = icmp sgt i32 %t, %clip
  %s1 = select i1 %c, i32 0, i32 %t
  %s2 = select i1 %c, i16 10, i16 %inc
  store i32 %s1, ptr %p
  %a = add i16 %s2, %r
  ret i16 %a
}

; CHECK-LABEL: @wide(
; CHECK:       br i1
; CHECK:       phi i32
define i32 @wide(i16 %a, i16 %b, i32 %x, i32 %y) {
  %c = icmp slt i16 %a, %b
  %s = select i1 %c, i32 %x, i32 %y
  ret i32 %s
}

; CHECK-LABEL: @single16(
; CHECK-NOT:   br
; CHECK:       select i1
define i16 @single16(i16 %a, i16 %b) {
  %c = icmp ult i16 %a, %b
  %s = select i1 %c, i16 4, i16 2
  ret i16 %s
}

; CHECK-LABEL: @logical(
; CHECK-NOT:   br
; CHECK:       select i1 %c1, i1 true, i1 %c2
; CHECK:       select i1 %c1, i1 true, i1 %c2
define i1 @logical(i16 %a, i16 %b, ptr %p) {
  %c1 = icmp ult i16 %a, %b
  %c2 = icmp eq i16 %a, 0
  %o1 = select i1 %c1, i1 true, i1 %c2
  %o2 = select i1 %c1, i1 true, i1 %c2
  store i1 %o1, ptr %p
  ret i1 %o2
}
