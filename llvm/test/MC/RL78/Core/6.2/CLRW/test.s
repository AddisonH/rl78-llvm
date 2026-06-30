# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: clrw ax ; encoding: [0xf6]
clrw ax

# CHECK-INST: clrw bc ; encoding: [0xf7]
clrw bc
