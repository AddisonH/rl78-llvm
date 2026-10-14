// What the driver adds for each optimization level.

// RUN: %clang --target=rl78 -Os -### -c %s 2>&1 | FileCheck %s
// RUN: %clang --target=rl78 -Oz -### -c %s 2>&1 | FileCheck %s
// RUN: %clang --target=rl78 -O2 -### -c %s 2>&1 | FileCheck %s
// RUN: %clang --target=rl78 -O3 -### -c %s 2>&1 | FileCheck %s
// RUN: %clang --target=rl78 -Os -fno-jump-tables -### -c %s 2>&1 | FileCheck %s --check-prefix=NOJT

// Inlining and jump tables are left to the optimization level (the inlining
// threshold is the target's: RL78TTIImpl::adjustInliningThreshold).
// CHECK-NOT: "-fno-inline"
// CHECK-NOT: "-fno-jump-tables"
// CHECK-NOT: "-inline-threshold

// NOJT: "-fno-jump-tables"

// These are the target's own choices now (unrolling preferences, tail merge
// size, pass configuration, target options) or were found to change nothing.
// RUN: %clang --target=rl78 -Os -### -c %s 2>&1 | FileCheck %s --check-prefix=RETIRED
// RUN: %clang --target=rl78 -O3 -### -c %s 2>&1 | FileCheck %s --check-prefix=RETIRED
// RETIRED-NOT: "-inline-threshold
// RETIRED-NOT: "-unroll-runtime
// RETIRED-NOT: "-enable-unroll-and-jam
// RETIRED-NOT: "-enable-dfa-jump-thread
// RETIRED-NOT: "-join-splitedges
// RETIRED-NOT: "--trap-unreachable
// RETIRED-NOT: "-split-spill-mode
// RETIRED-NOT: "-enable-scalar-pre
// RETIRED-NOT: "-unroll-threshold
// RETIRED-NOT: "-tail-merge-size
// RETIRED-NOT: "-disable-machine-licm
// RETIRED-NOT: "-disable-block-placement
// RETIRED-NOT: "-replexitval
// RETIRED-NOT: "-adce-remove-loops
// RETIRED-NOT: "-available-load-scan-limit

// When optimizing for size the linker also turns calls to the most called
// functions into CALLT.
// RUN: %clang --target=rl78 -Os -### %s 2>&1 | FileCheck %s --check-prefix=LINK-SIZE
// RUN: %clang --target=rl78 -Oz -### %s 2>&1 | FileCheck %s --check-prefix=LINK-SIZE
// RUN: %clang --target=rl78 -O2 -### %s 2>&1 | FileCheck %s --check-prefix=LINK-SPEED
// RUN: %clang --target=rl78 -Os -mno-relax -### %s 2>&1 | FileCheck %s --check-prefix=LINK-SPEED
// LINK-SIZE: "--relax" "--relax-callt"
// LINK-SPEED-NOT: "--relax-callt"
