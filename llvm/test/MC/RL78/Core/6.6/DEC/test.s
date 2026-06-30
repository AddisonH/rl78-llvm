# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: dec x                                   ; encoding: [0x90]
dec X

# CHECK-INST: dec a                                   ; encoding: [0x91]
dec A

# CHECK-INST: dec c                                   ; encoding: [0x92]
dec C

# CHECK-INST: dec b                                   ; encoding: [0x93]
dec B

# CHECK-INST: dec e                                   ; encoding: [0x94]
dec E

# CHECK-INST: dec d                                   ; encoding: [0x95]
dec D

# CHECK-INST: dec l                                   ; encoding: [0x96]
dec L

# CHECK-INST: dec h                                   ; encoding: [0x97]
dec H



# CHECK-INST: dec 0xffe20                          ; encoding: [0xb4,0x20]
dec 0xFFE20

# CHECK-INST: dec saddr                               ; encoding: [0xb4,A]
dec saddr


# CHECK-INST: dec !0xf2000                            ; encoding: [0xb0,0x00,0x20]
dec !0x2000

# CHECK-INST: dec [hl+18]                             ; encoding: [0x61,0x69,0x12]
dec [HL + 0x12]

# CHECK-INST: dec es:!0x2000                          ; encoding: [0x11,0xb0,0x00,0x20]
dec ES:!0x2000

# CHECK-INST: dec es:[hl+18]                          ; encoding: [0x11,0x61,0x69,0x12]
dec ES:[HL + 0x12]
