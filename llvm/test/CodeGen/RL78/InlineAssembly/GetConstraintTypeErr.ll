; RUN: not llc -mtriple=rl78 %s 2>&1 -o - | FileCheck %s

; CHECK: error: couldn't allocate input reg for constraint 'x'
define dso_local i8 @test_constraint_r_unknown(i8 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i8 asm sideeffect "add $0, #5", "=r,x"(i8 %0) #1
  ret i8 %2
}
