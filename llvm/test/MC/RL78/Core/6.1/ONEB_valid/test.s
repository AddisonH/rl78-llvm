# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: oneb a                                  ; encoding: [0xe1]
oneb A

# CHECK-INST: oneb x                                  ; encoding: [0xe0]
oneb X

# CHECK-INST: oneb b                                  ; encoding: [0xe3]
oneb B

# CHECK-INST: oneb c                                  ; encoding: [0xe2]
oneb C

# CHECK-INST: oneb 0xffe20                         ; encoding: [0xe4,0x20]
oneb 0xFFE20

# CHECK-INST: oneb !0xf2204                           ; encoding: [0xe5,0x04,0x22]
oneb !0x2204

# CHECK-INST: oneb es:!0x2204                         ; encoding: [0x11,0xe5,0x04,0x22]
oneb ES:!0x2204
