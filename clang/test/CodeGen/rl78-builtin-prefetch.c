// The rw and locality arguments of __builtin_prefetch are ints, which are 16
// bits on RL78; the intrinsic takes i32.
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -emit-llvm %s -o - | FileCheck %s

void f(char *p, int rw) {
  // CHECK: call void @llvm.prefetch.p0(ptr %{{.*}}, i32 0, i32 3, i32 1)
  __builtin_prefetch(p);
  // CHECK: call void @llvm.prefetch.p0(ptr %{{.*}}, i32 1, i32 2, i32 1)
  __builtin_prefetch(p, 1, 2);
}
