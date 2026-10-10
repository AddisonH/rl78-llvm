; Verifies the effect of the AdjustMemRefs pass in the case of
; indirect memory addressing with a global symbol base. The offset 
; is expected to be forced to the BC register.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = 
"e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@g = dso_local global [10000 x i8] zeroinitializer, align 1

define dso_local i8 @foo(i16 %c) {
entry:
  %arrayidx = getelementptr [10000 x i8], ptr @g, i16 0, i16 %c
  %0 = load i8, ptr %arrayidx, align 1
  ret i8 %0
}

; CHECK: movw bc, ax
; CHECK: mov a, LOWW(_g)[bc]
