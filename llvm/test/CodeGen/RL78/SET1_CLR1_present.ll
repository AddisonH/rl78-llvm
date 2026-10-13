; Verify that the set1 and clr1 are present in the RL78 assembly.

; RUN: llc -verify-machineinstrs < %s -mtriple=rl78 | FileCheck %s


define dso_local void @f1(i16 noundef %0) {
  %2 = alloca i16, align 2
  store i16 %0, ptr %2, align 2
  %3 = load i16, ptr %2, align 2
  %4 = icmp ne i16 %3, 0
  br i1 %4, label %bb1, label %bb2

bb1:
  %5 = load volatile i8, ptr inttoptr (i16 -208 to ptr), align 1
  %6 = and i8 %5, -2
  %7 = or i8 %6, 1
  store volatile i8 %7, ptr inttoptr (i16 -208 to ptr), align 1
  br label %bb3

bb2:
  %8 = load volatile i8, ptr inttoptr (i16 -208 to ptr), align 1
  %9 = and i8 %8, -2
  %10 = or i8 %9, 0
  store volatile i8 %10, ptr inttoptr (i16 -208 to ptr), align 1
  br label %bb3

bb3:
  ret void
}

define dso_local void @f2(i16 noundef %0) {
  %2 = alloca i16, align 2
  store i16 %0, ptr %2, align 2
  %3 = load i16, ptr %2, align 2
  %4 = icmp ne i16 %3, 0
  br i1 %4, label %bb1, label %bb2

bb1:
  %5 = load volatile i8, ptr inttoptr (i16 -208 to ptr), align 1
  %6 = and i8 %5, -9
  %7 = or i8 %6, 8
  store volatile i8 %7, ptr inttoptr (i16 -208 to ptr), align 1
  br label %bb3

bb2:
  %8 = load volatile i8, ptr inttoptr (i16 -208 to ptr), align 1
  %9 = and i8 %8, -9
  %10 = or i8 %9, 0
  store volatile i8 %10, ptr inttoptr (i16 -208 to ptr), align 1
  br label %bb3

bb3:
  ret void
}

define dso_local void @f3(i16 noundef %0) {
  %2 = alloca i16, align 2
  store i16 %0, ptr %2, align 2
  %3 = load i16, ptr %2, align 2
  %4 = icmp ne i16 %3, 0
  br i1 %4, label %bb1, label %bb2

bb1:
  %5 = load volatile i8, ptr inttoptr (i16 -208 to ptr), align 1
  %6 = and i8 %5, 127
  %7 = or i8 %6, -128
  store volatile i8 %7, ptr inttoptr (i16 -208 to ptr), align 1
  br label %bb3

bb2:
  %8 = load volatile i8, ptr inttoptr (i16 -208 to ptr), align 1
  %9 = and i8 %8, 127
  %10 = or i8 %9, 0
  store volatile i8 %10, ptr inttoptr (i16 -208 to ptr), align 1
  br label %bb3

bb3:
  ret void
}

; CHECK-DAG: set1{{[[:space:]]+}}0xfff30.0
; CHECK-DAG: clr1{{[[:space:]]+}}0xfff30.0

; CHECK-DAG: set1{{[[:space:]]+}}0xfff30.3
; CHECK-DAG: clr1{{[[:space:]]+}}0xfff30.3

; CHECK-DAG: set1{{[[:space:]]+}}0xfff30.7
; CHECK-DAG: clr1{{[[:space:]]+}}0xfff30.7
