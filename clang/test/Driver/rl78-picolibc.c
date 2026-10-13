// The C library is picolibc when the sysroot has picolibc.ld, and newlib with
// libgloss otherwise.

// RUN: rm -rf %t && mkdir -p %t/pico/lib %t/newlib/lib
// RUN: touch %t/pico/lib/picolibc.ld

// RUN: %clang --target=rl78 --sysroot=%t/pico -### %s 2>&1 | FileCheck %s --check-prefix=PICO
// RUN: %clang --target=rl78 --sysroot=%t/pico -fsim -### %s 2>&1 | FileCheck %s --check-prefix=PICO-SIM
// RUN: %clang --target=rl78 --sysroot=%t/pico -fnewlib-nano -### %s 2>&1 | FileCheck %s --check-prefix=PICO
// RUN: %clangxx --target=rl78 --sysroot=%t/pico -### %s 2>&1 | FileCheck %s --check-prefix=PICO-CXX
// RUN: %clang --target=rl78 --sysroot=%t/pico -nostartfiles -### %s 2>&1 | FileCheck %s --check-prefix=PICO-NOSTART
// RUN: %clang --target=rl78 --sysroot=%t/newlib -### %s 2>&1 | FileCheck %s --check-prefix=NEWLIB
// RUN: %clang --target=rl78 --sysroot=%t/pico -nostdlib -r -### %s 2>&1 | FileCheck %s --check-prefix=RELOC
// RUN: %clang --target=rl78 --sysroot=%t/newlib -nostdlib -r -### %s 2>&1 | FileCheck %s --check-prefix=RELOC
// RUN: %clang --target=rl78 --sysroot=%t/newlib -fsim -fnewlib-nano -### %s 2>&1 | FileCheck %s --check-prefix=NEWLIB-SIM

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

// NEWLIB-NOT: "--gc-sections"
// NEWLIB: "-T{{[^"]*}}rl78.ld"
// NEWLIB: "{{[^"]*}}crt0.o" "{{[^"]*}}clang_rt.crtbegin.o"
// NEWLIB: "-lnosys" "-lc" "-lm" "-lclang_rt.builtins" "{{[^"]*}}clang_rt.crtend.o" "{{[^"]*}}crtn.o"

// NEWLIB-SIM: "-T{{[^"]*}}rl78-sim.ld"
// NEWLIB-SIM: "-lsim" "-lc_nano" "-lm"

// A relocatable link takes no default linker script.
// RELOC-NOT: "-T
// RELOC-NOT: "--gc-sections"
