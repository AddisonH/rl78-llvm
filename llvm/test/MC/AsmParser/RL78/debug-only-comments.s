        # RUN: llvm-mc -triple rl78 -g -dwarf-version 4 < %s | FileCheck %s
        # RUN: llvm-mc -triple rl78 -g -dwarf-version 5 < %s | FileCheck %s
        # CHECK: .section .debug_info
        # CHECK: .section .debug_info
        # CHECK-NOT: .section
        # CHECK: .ascii "<stdin>"
