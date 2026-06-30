; RUN: llc -mtriple=rl78 < %s | FileCheck %s 

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

declare dso_local void @callee3(i16 noundef, i16 noundef, i16 noundef) local_unnamed_addr 
declare dso_local void @callee5(i16 noundef, i16 noundef, i16 noundef, i16 noundef, i16 noundef) local_unnamed_addr
declare dso_local void @callee_long(i32 noundef) local_unnamed_addr 
declare dso_local void @callee_struct4([2 x i16]) local_unnamed_addr
declare dso_local void @callee_struct5([5 x i8]) local_unnamed_addr
declare dso_local void @callee_ll(i64 noundef) local_unnamed_addr 
declare dso_local void @callee_var(i16 noundef, ...) local_unnamed_addr 


; Simple situation for AX, BC, DE registers. 
; CHECK-LABEL: _test_call_regs
; CHECK: movw de, #3
; CHECK-NEXT: movw bc, #2
; CHECK-NEXT: onew ax
define dso_local void @test_call_regs() local_unnamed_addr {
  tail call void @callee3(i16 noundef 1, i16 noundef 2, i16 noundef 3) 
  ret void
}

; If no registers available, arguments will go to stack. 
; CHECK-LABEL: _test_call_stack
; CHECK: subw sp, #4
; CHECK-NEXT: movw de, #3
; CHECK-NEXT: movw bc, #2
; CHECK-NEXT: movw ax, #5
; CHECK-NEXT: movw [sp+2], ax
; CHECK-NEXT: movw ax, #4
; CHECK-NEXT: movw [sp+0], ax
; CHECK-NEXT: onew ax
; CHECK-NEXT: call !_callee5
; CHECK-NEXT: addw sp, #4
define dso_local void @test_call_stack() local_unnamed_addr {
  tail call void @callee5(i16 noundef 1, i16 noundef 2, i16 noundef 3, i16 noundef 4, i16 noundef 5) 
  ret void
}

; Unsigned long lower 2 bytes go to AX and upper 2 bytes to BC.
; CHECK-LABEL: _test_call_4byte
; CHECK: movw bc, #4386
; CHECK: movw ax, #13124
define dso_local void @test_call_4byte() local_unnamed_addr {
  tail call void @callee_long(i32 noundef 287454020) 
  ret void
}

; Struct ≤ 4 bytes arguments go to registers.
; CHECK-LABEL: _test_call_struct4
; CHECK: movw bc, #2
; CHECK-NEXT: onew ax
define dso_local void @test_call_struct4() local_unnamed_addr {
  tail call void @callee_struct4([2 x i16] [i16 1, i16 2]) 
  ret void
}

; Struct ≥ 5 bytes arguments go to stack.
; CHECK-LABEL: _test_call_struct5
; CHECK: subw sp, #6
; CHECK-NEXT: mov [sp+4], #5
; CHECK-NEXT: movw ax, #1027
; CHECK-NEXT: movw [sp+2], ax
; CHECK-NEXT: movw ax, #513
; CHECK-NEXT: movw [sp+0], ax
; CHECK-NEXT: call !_callee_struct5
; CHECK-NEXT: addw sp, #6 
define dso_local void @test_call_struct5() local_unnamed_addr  {
  tail call void @callee_struct5([5 x i8] c"\01\02\03\04\05") 
  ret void
}

; 8-byte arguments go to stack.
; CHECK-LABEL: _test_call_ll
; CHECK: subw sp, #8
; CHECK-NEXT: movw ax, #4386
; CHECK-NEXT: movw [sp+6], ax
; CHECK-NEXT: movw ax, #13124
; CHECK-NEXT: movw [sp+4], ax
; CHECK-NEXT: movw ax, #21862
; CHECK-NEXT: movw [sp+2], ax
; CHECK-NEXT: movw ax, #30600
; CHECK-NEXT: movw [sp+0], ax
; CHECK-NEXT: call !_callee_ll
; CHECK-NEXT: addw sp, #8
define dso_local void @test_call_ll() local_unnamed_addr  {
  tail call void @callee_ll(i64 noundef 1234605616436508552) 
  ret void
}

; Variable arguments go to stack.
; CHECK-LABEL: _test_call_var
; CHECK: subw sp, #4
; CHECK-NEXT: movw ax, #3
; CHECK-NEXT: movw [sp+2], ax
; CHECK-NEXT: movw ax, #2
; CHECK-NEXT: movw [sp+0], ax
; CHECK-NEXT: onew ax
; CHECK-NEXT: call !_callee_var
define dso_local void @test_call_var() local_unnamed_addr #0 {
  tail call void (i16, ...) @callee_var(i16 noundef 1, i16 noundef 2, i16 noundef 3) #2
  ret void
}

; CHECK-LABEL: _test_call_far
; CHECK: movw de, #9029
; CHECK-NEXT: oneb a
define dso_local void @test_call_far() local_unnamed_addr #0 {
  tail call void @callee(ptr addrspace(2) noundef nonnull inttoptr (i32 74565 to ptr addrspace(2))) #2
  ret void
}

declare dso_local void @callee(ptr addrspace(2) noundef) local_unnamed_addr 


