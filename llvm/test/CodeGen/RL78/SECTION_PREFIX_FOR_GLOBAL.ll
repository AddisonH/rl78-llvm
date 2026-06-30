; Testing validity of section prefixes for global objects.

; RUN: llc -mtriple=rl78 < %s | FileCheck %s
; RUN: llc -mtriple=rl78 -mattr=+far-data < %s | FileCheck %s -check-prefix=FAR


define void @foo() {
entry:
  ret void
}
; CHECK: .text
; CHECK-LABEL: _foo:

define void @boo() addrspace(3) {
entry:
  ret void
}
; CHECK: .section{{[[:space:]]+}}.textf
; CHECK-LABEL: _boo:

@a =  constant i8 77, align 1 #0
; CHECK: .section{{[[:space:]]+}}.const
; CHECK: _a:
; CHECK-NEXT: 77
; FAR: .section{{[[:space:]]+}}.constf
; FAR: _a:
; FAR-NEXT: 77

@b = constant i8 77
; CHECK: .section{{[[:space:]]+}}.rodata
; CHECK: _b:
; CHECK-NEXT: 77
; FAR: .section{{[[:space:]]+}}.frodata
; FAR: _b:
; FAR-NEXT: 77

@c = global i8 77, align 1 #1
; CHECK: .section{{[[:space:]]+}}.sdata
; CHECK: _c:
; CHECK-NEXT: 77

@d = global i8 undef, align 1 #1
; CHECK: .section{{[[:space:]]+}}.sbss
; CHECK: _d:

@e = global i8 undef
; CHECK: .section{{[[:space:]]+}}.bss
; CHECK: _e:
; FAR: .section{{[[:space:]]+}}.bssf
; FAR: _e:

@f = global i8 77
; CHECK: .data
; CHECK: _f:
; CHECK-NEXT: 77
; FAR: .dataf
; FAR: _f:
; FAR-NEXT: 77

attributes #0 = { "use-renesas-naming" }
attributes #1 = { "saddr" }
