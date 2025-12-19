// RUN: llvm-mc -triple rl78 -asm-macro-max-nesting-depth=42 %s | FileCheck %s -check-prefix=CHECK_PASS
// RUN: not llvm-mc -triple rl78 %s 2> %t
// RUN: FileCheck -check-prefix=CHECK_FAIL < %t %s

.macro rec head, tail:vararg
 .ifnb \tail
 rec \tail
 .else
 .long 42
 .endif
.endm

.macro amplify macro, args:vararg
 \macro  \args \args \args \args
.endm

amplify rec 0 0 0 0 0 0 0 0 0 0

// CHECK_PASS: .long 42
// CHECK_FAIL: error: macros cannot be nested more than {{[0-9]+}} levels deep. Use -asm-macro-max-nesting-depth to increase this limit.
