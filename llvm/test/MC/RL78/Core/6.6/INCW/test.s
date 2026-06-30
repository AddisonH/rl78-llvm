# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: incw ax                                 ; encoding: [0xa1]
incw AX

# CHECK-INST: incw bc                                 ; encoding: [0xa3]
incw BC

# CHECK-INST: incw de                                 ; encoding: [0xa5]
incw DE

# CHECK-INST: incw hl                                 ; encoding: [0xa7]
incw HL


# CHECK-INST: incw 0xffe20                         ; encoding: [0xa6,0x20]
incw 0xFFE20

# CHECK-INST: incw saddrp                             ; encoding: [0xa6,A]
incw saddrp


# CHECK-INST: incw !0xf2000                           ; encoding: [0xa2,0x00,0x20]
incw !0x2000

# CHECK-INST: incw [hl+18]                            ; encoding: [0x61,0x79,0x12]
incw [HL + 0x12]

# CHECK-INST: incw es:!0x2000                         ; encoding: [0x11,0xa2,0x00,0x20]
incw ES:!0x2000

# CHECK-INST: incw es:[hl+18]                         ; encoding: [0x11,0x61,0x79,0x12]
incw ES:[HL + 0x12]
