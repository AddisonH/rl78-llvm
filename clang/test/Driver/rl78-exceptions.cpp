// RL78 has no exception handling: C++ exceptions are off by default, and
// asking for them is an error.

// RUN: %clang --target=rl78 -### -c %s 2>&1 | FileCheck %s --check-prefix=DEFAULT
// DEFAULT-NOT: "-fcxx-exceptions"
// DEFAULT-NOT: "-fexceptions"

// RUN: not %clang --target=rl78 -fexceptions -### -c %s 2>&1 | FileCheck %s --check-prefix=EH
// EH: error: unsupported option '-fexceptions' for target 'rl78

// RUN: not %clang --target=rl78 -fcxx-exceptions -### -c %s 2>&1 | FileCheck %s --check-prefix=CXXEH
// CXXEH: error: unsupported option '-fcxx-exceptions' for target 'rl78

// RUN: %clang --target=rl78 -fexceptions -fno-exceptions -### -c %s 2>&1 | FileCheck %s --check-prefix=DEFAULT
