; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _test_nop:
; CHECK: ; %bb.0:
; CHECK: 	nop
; CHECK: 	ret
define dso_local void @test_nop() local_unnamed_addr #0 {
  tail call void asm sideeffect "nop", ""() #1
  ret void
}

; CHECK: _test_halt:
; CHECK: ; %bb.0:
; CHECK: 	halt
; CHECK: 	ret
define dso_local void @test_halt() local_unnamed_addr #0 {
  tail call void asm sideeffect "halt", ""() #1
  ret void
}

; CHECK: _test_stop:
; CHECK: ; %bb.0:
; CHECK: 	stop
; CHECK: 	ret
define dso_local void @test_stop() local_unnamed_addr #0 {
  tail call void asm sideeffect "stop", ""() #1
  ret void
}

; CHECK: _test_brk:
; CHECK: ; %bb.0:
; CHECK: 	brk
; CHECK: 	ret
define dso_local void @test_brk() local_unnamed_addr #0 {
  tail call void asm sideeffect "brk", ""() #1
  ret void
}

; CHECK: _test_ei:
; CHECK: ; %bb.0:
; CHECK: 	ei
; CHECK: 	ret
define dso_local void @test_ei() local_unnamed_addr #0 {
  tail call void asm sideeffect "ei", ""() #1
  ret void
}

; CHECK: _test_di:
; CHECK: ; %bb.0:
; CHECK: 	di
; CHECK: 	ret
define dso_local void @test_di() local_unnamed_addr #0 {
  tail call void asm sideeffect "di", ""() #1
  ret void
}
