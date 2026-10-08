; Triple::computeDataLayout must know RL78 (opt on a module without a
; datalayout used to hit "Invalid arch"), and its default must match what
; RL78TargetMachine uses without far-code/far-data features.
; RUN: opt -S -mtriple=rl78 < %s | FileCheck %s
; RUN: llc -mtriple=rl78 -stop-after=pre-isel-intrinsic-lowering < %s -o - \
; RUN:   | FileCheck %s --check-prefix=TM
; CHECK: target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
; TM:    target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"

define void @f() {
  ret void
}
