# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: cmp0 a                                  ; encoding: [0xd1]
cmp0 A

# CHECK-INST: cmp0 x                                  ; encoding: [0xd0]
cmp0 X

# CHECK-INST: cmp0 b                                  ; encoding: [0xd3]
cmp0 B

# CHECK-INST: cmp0 c                                  ; encoding: [0xd2]
cmp0 C


# CHECK-INST: cmp0 0xffe20                         ; encoding: [0xd4,0x20]
cmp0 0xFFE20

# CHECK-INST: cmp0 saddr                              ; encoding: [0xd4,A]
cmp0 saddr


# CHECK-INST: cmp0 !0xf2000                           ; encoding: [0xd5,0x00,0x20]
cmp0 !0x2000

# CHECK-INST: cmp0 es:!0x2000                         ; encoding: [0x11,0xd5,0x00,0x20]
cmp0 ES:!0x2000
