; At -O0, a copy of an accumulator result gets the class
; RL78AXRP from instruction selection and has to be widened also in optnone
; functions, or it cannot stay live across the next pinned use of AX.
; RUN: llc -mtriple=rl78 -O0 < %s | FileCheck %s

; CHECK-LABEL: _mulo:
; CHECK: mulhu
; CHECK: ret
define i16 @mulo(i16 %a, i16 %b) noinline optnone {
  %sa = alloca i16, align 2
  %sb = alloca i16, align 2
  %sr = alloca i16, align 2
  store i16 %a, ptr %sa, align 2
  store i16 %b, ptr %sb, align 2
  %x = load i16, ptr %sa, align 2
  %y = load i16, ptr %sb, align 2
  %m = call { i16, i1 } @llvm.umul.with.overflow.i16(i16 %x, i16 %y)
  %o = extractvalue { i16, i1 } %m, 1
  %v = extractvalue { i16, i1 } %m, 0
  %big = icmp ugt i16 %v, 32767
  %bad = or i1 %o, %big
  store i16 %v, ptr %sr, align 2
  br i1 %bad, label %trap, label %ok

trap:
  call void @exit(i16 2)
  unreachable

ok:
  %r = load i16, ptr %sr, align 2
  ret i16 %r
}

declare void @exit(i16)
