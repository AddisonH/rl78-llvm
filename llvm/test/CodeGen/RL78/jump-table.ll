; RUN: llc -mtriple=rl78 < %s | FileCheck %s --check-prefix=NEAR
; RUN: llc -mtriple=rl78 -mattr=+far-code < %s | FileCheck %s --check-prefix=FAR

; A jump table holds 16-bit addresses and BR AX jumps to CS:AX, so a switch
; becomes a table only when all code is in the first 64 KiB and the table is
; near data. Other memory models compare.

declare void @a()
declare void @b()
declare void @c()
declare void @d()
declare void @e()
declare void @f()

define void @dispatch(i16 %x) optsize {
; NEAR-LABEL: _dispatch:
; NEAR: cmpw ax, #5
; NEAR: movw ax, #LJTI0_0
; NEAR: br ax
; NEAR: LJTI0_0:
; NEAR-NEXT: .short .LBB0_
;
; FAR-LABEL: _dispatch:
; FAR-NOT: br ax
; FAR-NOT: JTI
entry:
  switch i16 %x, label %done [
    i16 0, label %ca
    i16 1, label %cb
    i16 2, label %cc
    i16 3, label %cd
    i16 4, label %ce
    i16 5, label %cf
  ]
ca:
  tail call void @a()
  br label %done
cb:
  tail call void @b()
  br label %done
cc:
  tail call void @c()
  br label %done
cd:
  tail call void @d()
  br label %done
ce:
  tail call void @e()
  br label %done
cf:
  tail call void @f()
  br label %done
done:
  ret void
}
