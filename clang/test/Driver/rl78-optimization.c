// What the driver adds for each optimization level.

// RUN: %clang --target=rl78 -Os -### -c %s 2>&1 | FileCheck %s --check-prefixes=CHECK,SIZE
// RUN: %clang --target=rl78 -Oz -### -c %s 2>&1 | FileCheck %s --check-prefixes=CHECK,SIZE
// RUN: %clang --target=rl78 -O2 -### -c %s 2>&1 | FileCheck %s --check-prefixes=CHECK,SPEED
// RUN: %clang --target=rl78 -O3 -### -c %s 2>&1 | FileCheck %s --check-prefixes=CHECK,SPEED
// RUN: %clang --target=rl78 -Os -fno-jump-tables -### -c %s 2>&1 | FileCheck %s --check-prefix=NOJT

// Inlining and jump tables are left to the optimization level: for size, only
// callees about as small as a call are inlined.
// CHECK-NOT: "-fno-inline"
// CHECK-NOT: "-fno-jump-tables"
// SIZE: "-mllvm" "-inline-threshold=5"
// SPEED-NOT: "-inline-threshold=5"

// NOJT: "-fno-jump-tables"
