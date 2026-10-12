// The depth of __builtin_return_address/__builtin_frame_address is an
// unsigned int, which is 16 bits on RL78; the intrinsics take an i32. The
// result is converted to void *, which is in another address space with
// -mfar-code.
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -emit-llvm %s -o - | FileCheck %s --check-prefix=NEAR
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -target-feature +far-code -emit-llvm %s -o - | FileCheck %s --check-prefix=FARCODE

void *ra(void) { return __builtin_return_address(0); }
// NEAR-LABEL: @ra(
// NEAR: call ptr @llvm.returnaddress.p0(i32 0)
// FARCODE-LABEL: @ra(
// FARCODE: [[R:%.*]] = call addrspace(3) ptr addrspace(3) @llvm.returnaddress.p3(i32 0)
// FARCODE: addrspacecast ptr addrspace(3) [[R]] to ptr

void *fa(void) { return __builtin_frame_address(1); }
// NEAR-LABEL: @fa(
// NEAR: call ptr @llvm.frameaddress.p0(i32 1)
