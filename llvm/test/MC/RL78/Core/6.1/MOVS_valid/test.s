# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: movs [hl+16], x                         ; encoding: [0x61,0xce,0x10]
movs [HL+0x10],   X         ; [HL+byte], X

# CHECK-INST: movs es:[hl+16], x                      ; encoding: [0x11,0x61,0xce,0x10]
movs ES:[HL+0x10],   X         ; [HL+byte], X
