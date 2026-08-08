; Test the LowerCMPW, LowerCMPWMem functions.
; Ensure CMPW_rp_imm, CMPW_rp_memri instructions are lowered correctly.

; RUN: llc -mtriple=rl78 %s -o - | FileCheck %s

; CHECK: _aa:
; CHECK: 	cmpw ax, #1024

define dso_local i1 @aa(i16 noundef %0) local_unnamed_addr #0 {
  %2 = icmp ne i16 %0, 1024
  ret i1 %2
}

; CHECK: _af:
; CHECK: 	cmpw ax, [hl+2]

define dso_local i1 @af(i16 noundef %0, ptr nocapture noundef readonly %1) local_unnamed_addr #1 {
  %3 = getelementptr inbounds i16, ptr %1, i16 1
  %4 = load i16, ptr %3, align 2
  %5 = icmp ne i16 %4, %0
  ret i1 %5
}
