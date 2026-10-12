// RUN: %clang_cc1 -triple rl78 -fsyntax-only -Wunknown-pragmas -verify %s
// REQUIRES: rl78-registered-target

// The CC-RL spellings are not part of the language: the pragmas are unknown,
// __saddr and __callt are ordinary identifiers, and the intrinsics need
// <rl78intrin.h>. The attributes do the same job.

#pragma interrupt isr(vect=0x20) // expected-warning {{unknown pragma ignored}}
#pragma saddr fast               // expected-warning {{unknown pragma ignored}}
#pragma address (reg = 0xFFF00)  // expected-warning {{unknown pragma ignored}}

__attribute__((interrupt(vect = 0x20))) void isr(void);
__attribute__((saddr)) unsigned char fast;
__attribute__((callt)) void table(void);

int __saddr;
int __callt;

void f(void) {
  __nop(); // expected-error {{call to undeclared function '__nop'}}
  __builtin_rl78_nop();
}
