; Verify that bitwise OR/AND idioms on volatile i8 loads/stores produce set1/clr1.

; RUN: llc < %s -mtriple=rl78 | FileCheck %s


define dso_local void @f1(i8 noundef %0) {
  %2 = alloca i8, align 1
  store i8 %0, ptr %2, align 1
  %3 = load i8, ptr %2, align 1
  %4 = zext i8 %3 to i16
  %5 = icmp eq i16 1, %4
  br i1 %5, label %bb1, label %bb2

bb1:
  %6 = load volatile i8, ptr inttoptr (i16 -199 to ptr), align 1
  %7 = zext i8 %6 to i16
  %8 = or i16 %7, 1
  %9= trunc i16 %8 to i8
  store volatile i8 %9, ptr inttoptr (i16 -199 to ptr), align 1
  br label %bb3

bb2:
  %10 = load volatile i8, ptr inttoptr (i16 -199 to ptr), align 1
  %11 = zext i8 %10 to i16
  %12 = and i16 %11, 254
  %13 = trunc i16 %12 to i8
  store volatile i8 %13, ptr inttoptr (i16 -199 to ptr), align 1
  br label %bb3

bb3:
  ret void
}

define dso_local void @f2(i8 noundef %0) {
  %2 = alloca i8, align 1
  store i8 %0, ptr %2, align 1
  %3 = load i8, ptr %2, align 1
  %4 = zext i8 %3 to i16
  %5 = icmp eq i16 1, %4
  br i1 %5, label %bb1, label %bb2

bb1:
  %6 = load volatile i8, ptr inttoptr (i16 -199 to ptr), align 1
  %7 = zext i8 %6 to i16
  %8 = or i16 %7, 8
  %9 = trunc i16 %8 to i8
  store volatile i8 %9, ptr inttoptr (i16 -199 to ptr), align 1
  br label %bb3

bb2:
  %10 = load volatile i8, ptr inttoptr (i16 -199 to ptr), align 1
  %11 = zext i8 %10 to i16
  %12 = and i16 %11, 247
  %13 = trunc i16 %12 to i8
  store volatile i8 %13, ptr inttoptr (i16 -199 to ptr), align 1
  br label %bb3

bb3:
  ret void
}

define dso_local void @f3(i8 noundef %0) {
  %2 = alloca i8, align 1
  store i8 %0, ptr %2, align 1
  %3 = load i8, ptr %2, align 1
  %4 = zext i8 %3 to i16
  %5 = icmp eq i16 1, %4
  br i1 %5, label %bb1, label %bb2

bb1:
  %6 = load volatile i8, ptr inttoptr (i16 -199 to ptr), align 1
  %7 = zext i8 %6 to i16
  %8 = or i16 %7, 128
  %9 = trunc i16 %8 to i8
  store volatile i8 %9, ptr inttoptr (i16 -199 to ptr), align 1
  br label %bb3

bb2:
  %10 = load volatile i8, ptr inttoptr (i16 -199 to ptr), align 1
  %11 = zext i8 %10 to i16
  %12 = and i16 %11, 127
  %13 = trunc i16 %12 to i8
  store volatile i8 %13, ptr inttoptr (i16 -199 to ptr), align 1
  br label %bb3

bb3:
  ret void
}

; CHECK-DAG: set1{{[[:space:]]+}}0xfff39.0
; CHECK-DAG: clr1{{[[:space:]]+}}0xfff39.0

; CHECK-DAG: set1{{[[:space:]]+}}0xfff39.3
; CHECK-DAG: clr1{{[[:space:]]+}}0xfff39.3

; CHECK-DAG: set1{{[[:space:]]+}}0xfff39.7
; CHECK-DAG: clr1{{[[:space:]]+}}0xfff39.7
