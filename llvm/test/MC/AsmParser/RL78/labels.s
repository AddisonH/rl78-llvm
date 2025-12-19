// RUN: llvm-mc -triple rl78 %s | FileCheck %s

        .data
// CHECK: a:
a:
        .long 0
// CHECK: b:
"b":
        .long 0
// CHECK: a$b:
"a$b":
        .long 0

        .text
foo:
// CHECK: addw ax, !a$b
        addw ax, !"a$b"
// CHECK: addw ax, !a$b+10
        addw ax, !("a$b" + 10)

// CHECK: .set b$c, 10
"b$c" = 10
// CHECK: addw ax, !0xf000a
        addw ax, !"b$c"

// CHECK: .set "a 0", 11
        .set "a 0", 11

// CHECK: .long 11
        .long "a 0"

// XXCHCK: .section "a 1,a 2"
//.section "a 1", "a 2"

// CHECK: .globl "a 3"
        .globl "a 3"

// CHECK: .comm "a 6",1
        .comm "a 6", 1

// CHECK: .lcomm "a 7",1
        .lcomm "a 7", 1

// FIXME: We don't bother to support .lsym.

// CHECX: .lsym "a 8",1
//        .lsym "a 8", 1

// CHECK: .set "a 9", a-b
        .set "a 9", a - b

// CHECK: .long "a 9"
        .long "a 9"
