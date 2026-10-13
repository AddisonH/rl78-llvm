// The address of a label is in the program address space; with -mfar-code
// that is not the address space of the void * it is converted to.
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -emit-llvm %s -o - | FileCheck %s --check-prefix=NEAR
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -target-feature +far-code -emit-llvm %s -o - | FileCheck %s --check-prefix=FARCODE

int f(int i) {
  void *p = &&a;
  // NEAR: store ptr blockaddress(@f, %a), ptr %p
  // FARCODE: store ptr addrspacecast (ptr addrspace(3) blockaddress(@f, %a) to ptr), ptr %p
  if (i)
    p = &&b;
  goto *p;
a:
  return 1;
b:
  return 2;
}
