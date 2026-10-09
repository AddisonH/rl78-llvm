// The depth of __builtin_return_address/__builtin_frame_address is an
// unsigned int, which is 16 bits on RL78; the intrinsics take an i32. The
// result is converted to void *, which may be in another address space (far
// code with -mfar-code, far data with -mfar-data).
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -emit-llvm %s -o - | FileCheck %s --check-prefix=NEAR
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -target-feature +far-code -mfar-code -emit-llvm %s -o - | FileCheck %s --check-prefix=FARCODE
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -target-feature +far-data -mfar-data -emit-llvm %s -o - | FileCheck %s --check-prefix=FARDATA

void *ra(void) { return __builtin_return_address(0); }
// NEAR-LABEL: @ra(
// NEAR: call ptr @llvm.returnaddress.p0(i32 0)
// FARCODE-LABEL: @ra(
// FARCODE: [[R:%.*]] = call addrspace(3) ptr addrspace(3) @llvm.returnaddress.p3(i32 0)
// FARCODE: addrspacecast ptr addrspace(3) [[R]] to ptr

void *fa(void) { return __builtin_frame_address(1); }
// NEAR-LABEL: @fa(
// NEAR: call ptr @llvm.frameaddress.p0(i32 1)
// FARDATA-LABEL: @fa(
// FARDATA: [[F:%.*]] = call ptr addrspace(1) @llvm.frameaddress.p1(i32 1)
// FARDATA: addrspacecast ptr addrspace(1) [[F]] to ptr
