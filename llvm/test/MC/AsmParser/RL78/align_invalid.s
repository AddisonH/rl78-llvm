# RUN: not llvm-mc -triple rl78 < %s 2>&1 | FileCheck %s -check-prefix=ELF

.align 3
# ELF: error: alignment must be a power of 2


.align 32
# ELF-NOT: error


.align 0x100000000
# ELF:    error: alignment must be smaller than 2**32

