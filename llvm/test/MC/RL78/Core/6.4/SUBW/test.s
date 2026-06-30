# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: subw ax, #4626                          ; encoding: [0x24,0x12,0x12]
subw AX, #0x1212


# CHECK-INST: subw ax, bc                             ; encoding: [0x23]
subw AX, BC

# CHECK-INST: subw ax, de                             ; encoding: [0x25]
subw AX, DE

# CHECK-INST: subw ax, hl                             ; encoding: [0x27]
subw AX, HL



# CHECK-INST: subw ax, 0xffe20                     ; encoding: [0x26,0x20]
subw ax, 0xFFE20

# CHECK-INST: subw ax, saddr                          ; encoding: [0x26,A]
subw ax, saddr

# CHECK-INST: subw ax, !0xf2000                       ; encoding: [0x22,0x00,0x20]
subw AX, !0x2000

# CHECK-INST: subw ax, [hl+18]                        ; encoding: [0x61,0x29,0x12]
subw AX, [HL + 0x12]


# CHECK-INST: subw ax, es:!0x2000                     ; encoding: [0x11,0x22,0x00,0x20]
subw AX, ES:!0x2000

# CHECK-INST: subw ax, es:[hl+18]                     ; encoding: [0x11,0x61,0x29,0x12]
subw AX, ES:[HL + 0x12]
