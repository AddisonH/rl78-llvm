# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: cmps x, [hl+18]                         ; encoding: [0x61,0xde,0x12]
cmps X, [HL + 0x12]

# CHECK-INST: cmps x, es:[hl+18]                      ; encoding: [0x11,0x61,0xde,0x12]
cmps X, ES:[HL + 0x12]
