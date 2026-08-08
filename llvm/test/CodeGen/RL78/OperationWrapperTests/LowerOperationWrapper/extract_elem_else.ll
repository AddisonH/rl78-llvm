
; This test illustrates the second else branch in the case of an i32 EXTRACT_ELEMENT.
; The branch just modifies the i32 constant extract index to an i16 index.

; RUN: llc -mtriple=rl78 -mattr=+far-data %s -o - | FileCheck %s

define dso_local i16 @test_smulll(i64 noundef %0, i64 noundef %1, ptr nocapture noundef writeonly %2) local_unnamed_addr #0 {
  ret i16 0
}

; CHECK: _main:
; CHECK:  movw ax, [sp+22]
; CHECK:  movw [sp+24], ax
; CHECK:  movw ax, [sp+20]
; CHECK:  movw hl, ax

define dso_local i16 @main() local_unnamed_addr {
  %1 = alloca i64, align 2, addrspace(1)
  %2 = addrspacecast ptr addrspace(1) %1 to ptr
  %3 = call i16 @test_smulll(i64 16383, i64 2, ptr %2)
  %4 = icmp eq i16 %3, 0
  %5 = load i64, ptr addrspace(1) %1, align 2
  %6 = icmp eq i64 %5, 32766
  %7 = select i1 %4, i1 %6, i1 false
  br i1 %7, label %8, label %9

8:
  ret i16 1

9:
  ret i16 0
}
