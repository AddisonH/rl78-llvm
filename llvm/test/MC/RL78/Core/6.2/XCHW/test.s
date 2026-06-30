# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: xchw ax, bc                             ; encoding: [0x33]
xchw AX, BC

# CHECK-INST: xchw ax, de                             ; encoding: [0x35]
xchw AX, DE

# CHECK-INST: xchw ax, hl                             ; encoding: [0x37]
xchw AX, HL
