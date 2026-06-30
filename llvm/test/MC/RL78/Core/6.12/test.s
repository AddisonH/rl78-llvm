# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: br ax                                   ; encoding: [0x61,0xcb]
br AX

# CHECK-INST: br $0x70                                ; encoding: [0xef,0x70]
br $0x70

# CHECK-INST: br $!0x129                              ; encoding: [0xee,0x29,0x01]
br $!0x129

# CHECK-INST: br !0x2000                              ; encoding: [0xed,0x00,0x20]
br !0x2000

# CHECK-INST: br !!0xf2000                            ; encoding: [0xec,0x00,0x20,0x0f]
br !!0xf2000
