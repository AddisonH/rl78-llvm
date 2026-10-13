; RUN: llc -verify-machineinstrs -mtriple=rl78 -O2 < %s | FileCheck %s
; RUN: llc -mtriple=rl78 -O2 -stop-after=atomic-expand < %s | FileCheck %s --check-prefix=IR

; RL78 has no lock-free atomics: every atomic operation becomes an __atomic_*
; libcall, and the memory-order argument is a 16-bit int.

@s = global i16 0, align 2
@l = global i32 0, align 2

; IR-LABEL: define i16 @xchg16
; IR: call i16 @__atomic_exchange_2(ptr @s, i16 %v, i16 5)
; CHECK-LABEL: _xchg16:
; CHECK: movw de, #5
; CHECK: ___atomic_exchange_2
define i16 @xchg16(i16 %v) {
  %r = atomicrmw xchg ptr @s, i16 %v seq_cst, align 2
  ret i16 %r
}

; IR-LABEL: define i16 @add16
; IR: call i16 @__atomic_fetch_add_2(ptr @s, i16 %v, i16 2)
; CHECK-LABEL: _add16:
; CHECK: ___atomic_fetch_add_2
define i16 @add16(i16 %v) {
  %r = atomicrmw add ptr @s, i16 %v acquire, align 2
  ret i16 %r
}

; IR-LABEL: define i16 @load16
; IR: call i16 @__atomic_load_2(ptr @s, i16 5)
; CHECK-LABEL: _load16:
; CHECK: ___atomic_load_2
define i16 @load16() {
  %r = load atomic i16, ptr @s seq_cst, align 2
  ret i16 %r
}

; IR-LABEL: define void @store16
; IR: call void @__atomic_store_2(ptr @s, i16 %v, i16 3)
; CHECK-LABEL: _store16:
; CHECK: ___atomic_store_2
define void @store16(i16 %v) {
  store atomic i16 %v, ptr @s release, align 2
  ret void
}

; IR-LABEL: define i1 @cas16
; IR: call zeroext i1 @__atomic_compare_exchange_2(ptr @s, ptr %{{.*}}, i16 %n, i16 5, i16 2)
; CHECK-LABEL: _cas16:
; CHECK: ___atomic_compare_exchange_2
define i1 @cas16(i16 %e, i16 %n) {
  %r = cmpxchg ptr @s, i16 %e, i16 %n seq_cst acquire, align 2
  %ok = extractvalue { i16, i1 } %r, 1
  ret i1 %ok
}

; i32 is only 2-byte aligned, so the generic (unsized) libcall is used.
; IR-LABEL: define i32 @xchg32
; IR: call void @__atomic_exchange(i16 4, ptr @l, ptr %{{.*}}, ptr %{{.*}}, i16 5)
; CHECK-LABEL: _xchg32:
; CHECK: ___atomic_exchange
define i32 @xchg32(i32 %v) {
  %r = atomicrmw xchg ptr @l, i32 %v seq_cst, align 2
  ret i32 %r
}
