# RUN: llvm-mc -triple rl78 %s | FileCheck %s

# CHECK-NOT: foo
.extern foo
