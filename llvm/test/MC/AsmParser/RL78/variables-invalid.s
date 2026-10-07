// RUN: rm -rf %t && split-file %s %t
// RUN: not llvm-mc -triple rl78 %t/label.s -o /dev/null 2>&1 \
// RUN:   | FileCheck %t/label.s
// RUN: not llvm-mc -filetype=obj -triple rl78 %t/cycle.s -o /dev/null 2>&1 \
// RUN:   | FileCheck %t/cycle.s
// RUN: llvm-mc -filetype=obj -triple rl78 %t/reassign.s -o %t/reassign.o
// RUN: llvm-objdump -s -j .data %t/reassign.o | FileCheck %t/reassign.s

// Since LLVM 21 (upstream equate-cycle.s / reassign.s), '=' cycles are
// diagnosed when the value is evaluated rather than while parsing, and a
// variable may be reassigned after use (earlier uses keep the earlier value).

//--- label.s
        .data
t2_s0:
// CHECK: [[#@LINE+1]]:{{[0-9]+}}: error: redefinition of 't2_s0'
        t2_s0 = 2

//--- reassign.s
        .data
        t3_s0 = 5
        .long t3_s0
        t3_s0 = 1
        .long t3_s0
// CHECK: 0000 05000000 01000000

//--- cycle.s
        .data
// CHECK: [[#@LINE+2]]:{{[0-9]+}}: error: cyclic dependency detected for symbol 't0_v0'
// CHECK: [[#@LINE+1]]:{{[0-9]+}}: error: expression could not be evaluated
        t0_v0 = t0_v0 + 1

// CHECK: [[#@LINE+3]]:{{[0-9]+}}: error: cyclic dependency detected for symbol 't4_s1'
// CHECK: [[#@LINE+1]]:{{[0-9]+}}: error: expression could not be evaluated
        t4_s0 = t4_s1
        t4_s1 = t4_s2
        t4_s2 = t4_s0

// CHECK: [[#@LINE+3]]:{{[0-9]+}}: error: cyclic dependency detected for symbol 't5_s1'
// CHECK: [[#@LINE+1]]:{{[0-9]+}}: error: expression could not be evaluated
        t5_s0 = t5_s1 + 1
        t5_s1 = t5_s0
