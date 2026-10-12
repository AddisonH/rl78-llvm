// RUN: %clang_cc1 -triple rl78 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,NEAR
// RUN: %clang_cc1 -triple rl78 -target-feature +far-code -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,FAR
// REQUIRES: rl78-registered-target

// Data pointers are near (16 bits). __far makes a pointer or an object far
// (20-bit address in 32 bits, address space 2). Functions and pointers to
// them follow the code model: near, or far (address space 3) with far-code.

typedef void (*fn)(void);

_Static_assert(sizeof(void *) == 2, "near data pointer");
_Static_assert(sizeof(char __far *) == 4, "far data pointer");
_Static_assert(sizeof(char __near *) == 2, "__near is the default");
#ifdef __RL78_MEDIUM__
_Static_assert(sizeof(fn) == 4, "far function pointer");
#else
_Static_assert(sizeof(fn) == 2, "near function pointer");
#endif

// CHECK: @table = addrspace(2) constant [3 x i8]
const char __far table[3] = {1, 2, 3};

// NEAR: @handler = global ptr null
// FAR:  @handler = global ptr addrspace(3) null
fn handler;

// CHECK-LABEL: define{{.*}} @widen(
// CHECK: addrspacecast ptr %{{.*}} to ptr addrspace(2)
char __far *widen(char *p) { return p; }

// CHECK-LABEL: define{{.*}} @read(
// CHECK: load i8, ptr addrspace(2)
char read(const char __far *p) { return *p; }

// NEAR-LABEL: define{{.*}} void @call(
// NEAR: call void %
// FAR-LABEL: define{{.*}} void @call(
// FAR: call addrspace(3) void %
void call(void) { handler(); }
