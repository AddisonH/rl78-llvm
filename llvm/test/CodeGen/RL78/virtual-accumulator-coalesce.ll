; -rl78-virtual-acc: a byte compared several times stays in A when nothing
; else needs A meanwhile (RL78RegisterInfo::shouldCoalesce joins the copies
; into A), instead of living in another register with MOV A, r before each
; compare.
; RUN: llc -mtriple=rl78 -O2 -rl78-virtual-acc < %s | FileCheck %s

; CHECK-LABEL: _classify:
; CHECK:     mov a, [hl]
; CHECK-NOT: mov a, {{[xbcdehl]$}}
; CHECK-NOT: mov {{[xbcdehl]}}, a
; CHECK:     ret
define i16 @classify(ptr %p) {
entry:
  %c = load i8, ptr %p, align 1
  switch i8 %c, label %digit [
    i8 97, label %a
    i8 98, label %b
    i8 44, label %comma
  ]
a:
  br label %ret
b:
  br label %ret
comma:
  br label %ret
digit:
  %d = add i8 %c, -48
  %isdigit = icmp ult i8 %d, 10
  %r = select i1 %isdigit, i16 4, i16 0
  br label %ret
ret:
  %v = phi i16 [ 1, %a ], [ 2, %b ], [ 3, %comma ], [ %r, %digit ]
  ret i16 %v
}
