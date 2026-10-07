// RUN: not llvm-mc -triple rl78 %s 2>&1 | FileCheck %s

// RL78 has no '@' relocation specifiers. LLVM 17's generic parser accepted
// e.g. a@GOTPCREL and then silently dropped it (a plain R_RL78_DIR32U was
// emitted); since LLVM 21 specifiers are target-defined and these are errors.

// CHECK: :[[#@LINE+1]]:{{[0-9]+}}: error: unexpected token
.long 10 + 4@GOTPCREL
// CHECK: :[[#@LINE+1]]:{{[0-9]+}}: error: unexpected token
.long a + 4@GOTPCREL
// CHECK: :[[#@LINE+1]]:{{[0-9]+}}: error: unexpected token
.long (a + b)@GOTPCREL
// CHECK: :[[#@LINE+1]]:{{[0-9]+}}: error: unexpected token
.long 10 + b + 4@GOTPCREL
