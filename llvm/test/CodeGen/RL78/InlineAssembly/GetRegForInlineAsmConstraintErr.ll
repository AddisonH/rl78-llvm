; RUN: not llc -mtriple=rl78 %s 2>&1 -o - | FileCheck %s

; "r" takes integers of 8 bits or a multiple of 16, not floating point.

; CHECK: error: could not allocate output register for constraint 'r'
define dso_local float @test_weight_eerr(float noundef returned %0) local_unnamed_addr #0 {
  %2 = tail call float asm sideeffect "add $0, #5", "=r,r"(float %0) #1, !srcloc !3
  ret float %0
}

!3 = !{i64 127}
