; RUN: not llc -mtriple=rl78 %s 2>&1 -o - | FileCheck %s

; CHECK: error: couldn't allocate output register for constraint 'r'
define dso_local i32 @test_weight_eerr(i32 noundef returned %0) local_unnamed_addr #0 {
  %2 = tail call i32 asm sideeffect "add $0, #5", "=r,r"(i32 %0) #1, !srcloc !3
  ret i32 %0
}

!3 = !{i64 127}
