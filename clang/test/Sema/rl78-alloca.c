// RUN: %clang_cc1 -triple rl78 -fsyntax-only -verify %s

// RL78's frame has a fixed size: __builtin_alloca takes a constant size only.

void use(void *);

void f(unsigned n) {
  use(__builtin_alloca(8));
  use(__builtin_alloca(n)); // expected-error {{dynamic stack allocation is not supported for the current target}}
}
