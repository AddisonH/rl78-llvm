; This tests verifies the lowering of an i32 TargetGlobalAddress. The result should be a build pair
; containing the low and high parts of the TargetGlobalAddress.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _main:
; CHECK: 	br !!_atexit

define dso_local i16 @main() local_unnamed_addr addrspace(3) #2 {
  %1 = tail call addrspace(3) i16 @atexit() #4
  ret i16 %1
}

declare dso_local i16 @atexit() local_unnamed_addr addrspace(3) #3
