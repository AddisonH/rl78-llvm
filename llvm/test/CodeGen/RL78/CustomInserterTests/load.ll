; Test the Lower8bitADst, LowerToHLByteOrWordBC functions.
; Ensure the LOAD8_r_esrpi instruction is lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

@p = dso_local local_unnamed_addr global i8 0, align 1

; CHECK: _aj:
; CHECK: .LBB0_3:
; CHECK: 	movw ax, es:LOWW(_p)[b]

define dso_local i16 @aj(i8 noundef %0) local_unnamed_addr #0 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds i8, ptr @p, i16 %2
  %4 = addrspacecast ptr %3 to ptr addrspace(2)
  %5 = load i16, ptr addrspace(2) %4, align 2
  ret i16 %5
}

; CHECK: _an:
; CHECK: 	mov a, x
; CHECK: 	mov es, a
; CHECK: 	mov a, es:1000[bc]

define dso_local i8 @an(ptr addrspace(2) nocapture noundef readonly %0) local_unnamed_addr #1 {
  %2 = getelementptr inbounds i8, ptr addrspace(2) %0, i16 1000
  %3 = load i8, ptr addrspace(2) %2, align 1
  ret i8 %3
}
