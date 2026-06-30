# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: addw ax, #4626                          ; encoding: [0x04,0x12,0x12]
addw AX, #0x1212

# CHECK-INST: addw ax, ax                             ; encoding: [0x01]
addw AX, AX

# CHECK-INST: addw ax, bc                             ; encoding: [0x03]
addw AX, BC

# CHECK-INST: addw ax, de                             ; encoding: [0x05]
addw AX, DE

# CHECK-INST: addw ax, hl                             ; encoding: [0x07]
addw AX, HL



# CHECK-INST: addw ax, 0xffe20                     ; encoding: [0x06,0x20]
addw ax, 0xFFE20

# CHECK-INST: addw ax, saddr                          ; encoding: [0x06,A]
addw ax, saddr



# CHECK-INST: addw ax, !0xf2000                       ; encoding: [0x02,0x00,0x20]
addw AX, !0x2000


# CHECK-INST: addw ax, [hl+18]                        ; encoding: [0x61,0x09,0x12]
addw AX, [HL + 0x12]

# CHECK-INST: addw ax, es:!0x2000                     ; encoding: [0x11,0x02,0x00,0x20]
addw AX, ES:!0x2000

# CHECK-INST: addw ax, es:[hl+18]                     ; encoding: [0x11,0x61,0x09,0x12]
addw AX, ES:[HL + 0x12]
