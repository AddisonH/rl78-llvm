// RUN: %clang_cc1 -triple rl78 -fsyntax-only -verify %s
// REQUIRES: rl78-registered-target

// A near pointer converts to a far one; the other way needs a cast.

char __far *widen(char *p) { return p; }
char *narrow(char __far *p) {
  return p; // expected-error {{changes address space of pointer}}
}
char *forced(char __far *p) { return (char *)p; }

void vla(int n) {
  int a[n]; // expected-error {{variable length arrays are not supported for the current target}}
}
