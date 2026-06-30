# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: not1 cy                                 ; encoding: [0x71,0xc0]
not1 CY
