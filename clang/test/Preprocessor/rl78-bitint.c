// RL78 does not support _BitInt, so __BITINT_MAXWIDTH__ is not defined.
// RUN: %clang_cc1 -E -dM -triple rl78-unknown-elf < /dev/null | FileCheck %s
// RUN: %clang_cc1 -E -dM -x c++ -triple rl78-unknown-elf < /dev/null | FileCheck %s
// CHECK-NOT: __BITINT_MAXWIDTH__
// CHECK: #define __INT_WIDTH__ 16
// CHECK-NOT: __BITINT_MAXWIDTH__
