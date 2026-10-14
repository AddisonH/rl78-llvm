; RUN: opt -mtriple=rl78 -passes=inline -pass-remarks=inline \
; RUN:   -pass-remarks-missed=inline -disable-output %s 2>&1 | FileCheck %s
; RUN: opt -mtriple=rl78 -passes=inline -pass-remarks=inline \
; RUN:   -pass-remarks-missed=inline -codegen-opt-level=3 -disable-output %s 2>&1 \
; RUN:   | FileCheck %s --check-prefix=O3

; A call is about as small as code gets on RL78: an optsize caller inlines
; with the minsize threshold, 5 (7 with the single block bonus, which
; minsize does not get). At -O3 (CodeGenOptLevel::Aggressive) the threshold
; is 350 higher.

declare void @g(i16)

define void @leaf(i16 %x) {
  %a = add i16 %x, 1
  %b = mul i16 %a, %x
  %c = xor i16 %b, %a
  %d = mul i16 %c, %b
  %e = add i16 %d, %c
  call void @g(i16 %e)
  call void @g(i16 %d)
  ret void
}

define void @optsize(i16 %x) optsize {
  call void @leaf(i16 %x)
  ret void
}

define void @minsize(i16 %x) optsize minsize {
  call void @leaf(i16 %x)
  ret void
}

define void @speed(i16 %x) {
  call void @leaf(i16 %x)
  ret void
}

; CHECK-DAG: 'leaf' not inlined into 'optsize' because too costly to inline (cost=60, threshold=7)
; CHECK-DAG: 'leaf' not inlined into 'minsize' because too costly to inline (cost=60, threshold=5)
; CHECK-DAG: 'leaf' inlined into 'speed' with (cost=60, threshold=337)

; O3: 'leaf' inlined into 'speed' with (cost=60, threshold=862)
