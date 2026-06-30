# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: cmpw ax, #4626                          ; encoding: [0x44,0x12,0x12]
cmpw AX, #0x1212

# CHECK-INST: cmpw ax, bc                             ; encoding: [0x43]
cmpw AX, BC

# CHECK-INST: cmpw ax, de                             ; encoding: [0x45]
cmpw AX, DE

# CHECK-INST: cmpw ax, hl                             ; encoding: [0x47]
cmpw AX, HL



# CHECK-INST: cmpw ax, 0xffe20                     ; encoding: [0x46,0x20]
cmpw ax, 0xFFE20

# CHECK-INST: cmpw ax, saddr                          ; encoding: [0x46,A]
cmpw ax, saddr


# CHECK-INST: cmpw ax, !0xf2000                       ; encoding: [0x42,0x00,0x20]
cmpw AX, !0x2000

# CHECK-INST: cmpw ax, [hl+18]                        ; encoding: [0x61,0x49,0x12]
cmpw AX, [HL + 0x12]


# CHECK-INST: cmpw ax, es:!0x2000                     ; encoding: [0x11,0x42,0x00,0x20]
cmpw AX, ES:!0x2000

# CHECK-INST: cmpw ax, es:[hl+18]                     ; encoding: [0x11,0x61,0x49,0x12]
cmpw AX, ES:[HL + 0x12]
