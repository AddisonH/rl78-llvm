# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: decw ax                                 ; encoding: [0xb1]
decw AX

# CHECK-INST: decw bc                                 ; encoding: [0xb3]
decw BC

# CHECK-INST: decw de                                 ; encoding: [0xb5]
decw DE

# CHECK-INST: decw hl                                 ; encoding: [0xb7]
decw HL


# CHECK-INST: decw 0xffe20                         ; encoding: [0xb6,0x20]
decw 0xFFE20

# CHECK-INST: decw saddrp                             ; encoding: [0xb6,A]
decw saddrp


# CHECK-INST: decw !0xf2000                           ; encoding: [0xb2,0x00,0x20]
decw !0x2000

# CHECK-INST: decw [hl+18]                            ; encoding: [0x61,0x89,0x12]
decw [HL + 0x12]

# CHECK-INST: decw es:!0x2000                         ; encoding: [0x11,0xb2,0x00,0x20]
decw ES:!0x2000

# CHECK-INST: decw es:[hl+18]                         ; encoding: [0x11,0x61,0x89,0x12]
decw ES:[HL + 0x12]
