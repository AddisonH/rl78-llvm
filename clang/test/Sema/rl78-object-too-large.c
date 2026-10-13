// A variable that is larger than size_t can express is diagnosed, in the
// default address space and in the far one.
// RUN: %clang_cc1 -triple rl78-unknown-unknown-elf -fsyntax-only -verify %s

struct S {
  char a[40000];
  char b[40000];
};

struct S g; // expected-error {{'struct S' is too large for the address space (maximum allowed size of 65'535 bytes)}}
struct S __attribute__((address_space(2))) h; // expected-error {{is too large for the address space (maximum allowed size of 65'535 bytes)}}
extern struct S e; // a declaration only
struct { char a[40000]; } ok;

void f(void) {
  struct S l; // expected-error {{'struct S' is too large for the address space}}
}
