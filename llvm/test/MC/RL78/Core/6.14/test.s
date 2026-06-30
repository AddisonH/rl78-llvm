# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: skc                                     ; encoding: [0x61,0xc8]
skc

# CHECK-INST: sknc                                    ; encoding: [0x61,0xd8]
sknc

# CHECK-INST: skz                                     ; encoding: [0x61,0xe8]
skz

# CHECK-INST: sknz                                    ; encoding: [0x61,0xf8]
sknz

# CHECK-INST: skh                                     ; encoding: [0x61,0xe3]
skh

# CHECK-INST: sknh                                    ; encoding: [0x61,0xf3]
sknh
