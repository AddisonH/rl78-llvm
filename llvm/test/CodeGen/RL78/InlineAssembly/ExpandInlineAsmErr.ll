; RUN: not llc -mtriple=rl78 %s 2>&1 -o - | FileCheck %s

; CHECK: <inline asm>:1:2: error: invalid instruction mnemonic
; CHECK:         foo
define dso_local void @test_unknown_asm() local_unnamed_addr #0 {
  tail call void asm sideeffect "foo", ""() #1
  ret void
}
