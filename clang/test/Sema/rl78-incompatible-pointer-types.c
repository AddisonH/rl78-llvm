// RL78 keeps -Wincompatible-pointer-types a warning by default in C (the
// vendor's LLVM 17 toolchain and CC-RL behaviour); other targets make it an
// error.
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -fsyntax-only -verify=warn %s
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -fsyntax-only -w -verify=none %s
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -fsyntax-only -Werror -verify=err %s
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -fsyntax-only -Wno-incompatible-pointer-types -verify=none %s
// RUN: %clang_cc1 -triple x86_64-unknown-linux -fsyntax-only -verify=err %s
// none-no-diagnostics

int i;
char *p = &i; // warn-warning {{incompatible pointer types initializing 'char *' with an expression of type 'int *'}} \
              // err-error {{incompatible pointer types initializing 'char *' with an expression of type 'int *'}}
