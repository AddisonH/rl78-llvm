// RUN: llvm-mc -g -triple rl78  %s | FileCheck -check-prefix=CHECK-DEFAULT %s
// RUN: llvm-mc -g -triple rl78 %s -filetype=obj | obj2yaml | FileCheck -check-prefix=CHECK-DEBUG %s

// Test for Bug 38695
// This testcase has a single function and a .file directive
// without the [file-num] argument.  When compiled with -g,
// this testcase will not report error, and generate new
// debug info.

        .file "hello"
.text

f1:
        nop
.size f1, .-f1

// CHECK-DEFAULT: .file "hello"

// CHECK-DEBUG:  Sections:
// CHECK-DEBUG:  - Name:            .text
// CHECK-DEBUG:  - Name:            .debug_info
// CHECK-DEBUG:  - Name:            .rela.debug_info
// CHECK-DEBUG:    Info:            .debug_info
// CHECK-DEBUG:  Symbols:
