# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: and a, #18                              ; encoding: [0x5c,0x12]
and A, #0x12


# CHECK-INST: and 0xffe20, #18                     ; encoding: [0x5a,0x20,0x12]
and 0xFFE20, #0x12

# CHECK-INST: and saddr, #18                          ; encoding: [0x5a,A,0x12]
and saddr, #0x12


# CHECK-INST: and a, x                                ; encoding: [0x61,0x58]
and A, X

# CHECK-INST: and a, c                                ; encoding: [0x61,0x5a]
and A, C

# CHECK-INST: and a, b                                ; encoding: [0x61,0x5b]
and A, B

# CHECK-INST: and a, e                                ; encoding: [0x61,0x5c]
and A, E

# CHECK-INST: and a, d                                ; encoding: [0x61,0x5d]
and A, D

# CHECK-INST: and a, l                                ; encoding: [0x61,0x5e]
and A, L

# CHECK-INST: and a, h                                ; encoding: [0x61,0x5f]
and A, H



# CHECK-INST: and x, a                                ; encoding: [0x61,0x50]
and X, A

# CHECK-INST: and a, a                                ; encoding: [0x61,0x51]
and A, A

# CHECK-INST: and c, a                                ; encoding: [0x61,0x52]
and C, A

# CHECK-INST: and b, a                                ; encoding: [0x61,0x53]
and B, A

# CHECK-INST: and e, a                                ; encoding: [0x61,0x54]
and E, A

# CHECK-INST: and d, a                                ; encoding: [0x61,0x55]
and D, A

# CHECK-INST: and l, a                                ; encoding: [0x61,0x56]
and L, A

# CHECK-INST: and h, a                                ; encoding: [0x61,0x57]
and H, A



# CHECK-INST: and a, 0xffe20                       ; encoding: [0x5b,0x20]
and A, 0xFFE20

# CHECK-INST: and a, !0xf2000                         ; encoding: [0x5f,0x00,0x20]
and A, !0x2000

# CHECK-INST: and a, [hl]                             ; encoding: [0x5d]
and A, [HL]

# CHECK-INST: and a, [hl+18]                          ; encoding: [0x5e,0x12]
and A, [HL+0x12]



# CHECK-INST: and a, [hl+b]                           ; encoding: [0x61,0xd0]
and A, [HL+B]

# CHECK-INST: and a, [hl+c]                           ; encoding: [0x61,0xd2]
and A, [HL+C]



# CHECK-INST: and a, es:!0x2000                       ; encoding: [0x11,0x5f,0x00,0x20]
and A, ES:!0x2000

# CHECK-INST: and a, es:[hl]                          ; encoding: [0x11,0x5d]
and A, ES:[HL]

# CHECK-INST: and a, es:[hl+18]                       ; encoding: [0x11,0x5e,0x12]
and A, ES:[HL+0x12]

# CHECK-INST: and a, es:[hl+b]                        ; encoding: [0x11,0x61,0xd0]
and A, ES:[HL+B]

# CHECK-INST: and a, es:[hl+c]                        ; encoding: [0x11,0x61,0xd2]
and A, ES:[HL+C]
