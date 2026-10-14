// The C library is picolibc: its linker script, start-up object and
// libraries.

// RUN: %clang --target=rl78 -### %s 2>&1 | FileCheck %s --check-prefix=PICO
// RUN: %clang --target=rl78 -fsim -### %s 2>&1 | FileCheck %s --check-prefix=PICO-SIM
// RUN: %clangxx --target=rl78 -### %s 2>&1 | FileCheck %s --check-prefix=PICO-CXX
// RUN: %clang --target=rl78 -nostartfiles -### %s 2>&1 | FileCheck %s --check-prefix=PICO-NOSTART
// RUN: %clang --target=rl78 -nostdlib -r -### %s 2>&1 | FileCheck %s --check-prefix=RELOC

// PICO-NOT: "--gc-sections"
// PICO: "-T{{[^"]*}}picolibc.ld"
// PICO: "{{[^"]*}}lib{{/|\\\\}}crt0.o"
// PICO-NOT: crtbegin
// PICO: "-ldummyhost" "-lc" "-lclang_rt.builtins"
// PICO-NOT: "-lm"
// PICO-NOT: crtend
// PICO-NOT: crtn.o

// PICO-SIM: "-T{{[^"]*}}picolibc.ld"
// PICO-SIM: "{{[^"]*}}crt0-semihost.o"
// PICO-SIM: "-lsemihost" "-lc" "-lclang_rt.builtins"

// PICO-CXX: "--gc-sections"
// PICO-CXX: "-T{{[^"]*}}picolibcpp.ld"
// PICO-CXX: "-lc++" "-lc++abi" "-ldummyhost" "-lc"

// PICO-NOSTART-NOT: crt0
// PICO-NOSTART: "-ldummyhost" "-lc"

// A relocatable link takes no default linker script.
// RELOC-NOT: "-T
// RELOC-NOT: "--gc-sections"

// The newlib options are gone with newlib.
// RUN: not %clang --target=rl78 -fnewlib-nano -### %s 2>&1 | FileCheck %s --check-prefix=NANO
// NANO: error: unknown argument: '-fnewlib-nano'
