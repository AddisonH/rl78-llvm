// RUN: %clang_cc1 -triple rl78 -ffreestanding -emit-llvm -o - %s | FileCheck %s
// REQUIRES: rl78-registered-target

// The Renesas names of the RL78 intrinsics come from <rl78intrin.h>; the
// compiler itself only knows the __builtin_rl78_ ones.

#include <rl78intrin.h>

unsigned char v;

// CHECK-LABEL: define{{.*}} @control(
// CHECK: call void @llvm.rl78.di()
// CHECK: call void @llvm.rl78.nop()
// CHECK: call void @llvm.rl78.ei()
// CHECK: call void @llvm.rl78.halt()
void control(void) {
  __DI();
  __nop();
  __EI();
  __halt();
}

// CHECK-LABEL: define{{.*}} @bits(
// CHECK: call void @llvm.rl78.set1.p0(ptr @v, i8 3)
// CHECK: call void @llvm.rl78.clr1.p0(ptr @v, i8 0)
void bits(void) {
  __set1(&v, 3);
  __clr1(&v, 0);
}

// CHECK-LABEL: define{{.*}} @arith(
// CHECK: call i32 @llvm.rl78.mului(i16 %{{.*}}, i16 %{{.*}})
// CHECK: call i32 @llvm.rl78.divul(i32 %{{.*}}, i16 %{{.*}})
unsigned long arith(unsigned a, unsigned b) {
  return __divul(__mului(a, b), b);
}
