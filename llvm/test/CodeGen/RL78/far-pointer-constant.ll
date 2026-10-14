; RUN: llc -mtriple=rl78 < %s | FileCheck %s
; RUN: llc -mtriple=rl78 -filetype=obj < %s | llvm-readelf -r - \
; RUN:   | FileCheck %s --check-prefix=RELOC

; A far pointer to a near object is one 32-bit value: the near address in
; the last 64 KiB (data, and the mirror of constants) or the first (code).

@k = constant i16 5
@d = global i16 6
@fd = addrspace(2) global i16 7

define void @f() {
  ret void
}

; CHECK-LABEL: _pk:
; CHECK-NEXT:  .long SMRLW(_k)+983040
@pk = global ptr addrspace(2) addrspacecast (ptr @k to ptr addrspace(2))

; CHECK-LABEL: _pk2:
; CHECK-NEXT:  .long SMRLW(_k+2)+983040
@pk2 = global ptr addrspace(2) addrspacecast (ptr getelementptr (i8, ptr @k, i16 2) to ptr addrspace(2))

; CHECK-LABEL: _pd:
; CHECK-NEXT:  .long LOWW(_d)+983040
@pd = global ptr addrspace(2) addrspacecast (ptr @d to ptr addrspace(2))

; CHECK-LABEL: _pfd:
; CHECK-NEXT:  .long _fd
@pfd = global ptr addrspace(2) @fd

; CHECK-LABEL: _pf:
; CHECK-NEXT:  .long LOWW(_f)
@pf = global ptr addrspace(3) addrspacecast (ptr @f to ptr addrspace(3))

; In an aggregate the value keeps its place.
; CHECK-LABEL: _s:
; CHECK-NEXT:  .byte 1
; CHECK-NEXT:  .skip 1
; CHECK-NEXT:  .long LOWW(_d)+983040
; CHECK-NEXT:  .short 9
@s = global { i8, ptr addrspace(2), i16 } { i8 1, ptr addrspace(2) addrspacecast (ptr @d to ptr addrspace(2)), i16 9 }

; The constant is pushed by a relocation against no symbol.
; RELOC:      R_RL78_OPlowW_SMIR {{.*}} _k + 0
; RELOC-NEXT: R_RL78_SYM f0000
; RELOC-NEXT: R_RL78_OPadd
; RELOC-NEXT: R_RL78_ABS32U
