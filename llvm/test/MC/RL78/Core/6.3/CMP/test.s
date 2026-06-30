# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: cmp a, #18                              ; encoding: [0x4c,0x12]
cmp A, #0x12


# CHECK-INST: cmp 0xffe20, #18                     ; encoding: [0x4a,0x20,0x12]
cmp 0xFFE20, #0x12 

# CHECK-INST: cmp saddr, #18                          ; encoding: [0x4a,A,0x12]
cmp saddr, #0x12



# CHECK-INST: cmp a, x                                ; encoding: [0x61,0x48]
cmp A, X

# CHECK-INST: cmp a, c                                ; encoding: [0x61,0x4a]
cmp A, C

# CHECK-INST: cmp a, b                                ; encoding: [0x61,0x4b]
cmp A, B

# CHECK-INST: cmp a, e                                ; encoding: [0x61,0x4c]
cmp A, E

# CHECK-INST: cmp a, d                                ; encoding: [0x61,0x4d]
cmp A, D

# CHECK-INST: cmp a, l                                ; encoding: [0x61,0x4e]
cmp A, L

# CHECK-INST: cmp a, h                                ; encoding: [0x61,0x4f]
cmp A, H



# CHECK-INST: cmp x, a                                ; encoding: [0x61,0x40]
cmp X, A

# CHECK-INST: cmp a, a                                ; encoding: [0x61,0x41]
cmp A, A

# CHECK-INST: cmp c, a                                ; encoding: [0x61,0x42]
cmp C, A

# CHECK-INST: cmp b, a                                ; encoding: [0x61,0x43]
cmp B, A

# CHECK-INST: cmp e, a                                ; encoding: [0x61,0x44]
cmp E, A

# CHECK-INST: cmp d, a                                ; encoding: [0x61,0x45]
cmp D, A

# CHECK-INST: cmp l, a                                ; encoding: [0x61,0x46]
cmp L, A

# CHECK-INST: cmp h, a                                ; encoding: [0x61,0x47]
cmp H, A



# CHECK-INST: cmp a, 0xffe20                       ; encoding: [0x4b,0x20]
cmp A, 0xFFE20

# CHECK-INST: cmp a, !0xf2000                         ; encoding: [0x4f,0x00,0x20]
cmp A, !0x2000

# CHECK-INST: cmp a, [hl]                             ; encoding: [0x4d]
cmp A, [HL]

# CHECK-INST: cmp a, [hl+18]                          ; encoding: [0x4e,0x12]
cmp A, [HL+0x12]



# CHECK-INST: cmp a, [hl+b]                           ; encoding: [0x61,0xc0]
cmp A, [HL+B]

# CHECK-INST: cmp a, [hl+c]                           ; encoding: [0x61,0xc2]
cmp A, [HL+C]


# CHECK-INST: cmp !0xf2000, #18                       ; encoding: [0x40,0x00,0x20,0x12]
cmp !0x2000, #0x12



# CHECK-INST: cmp a, es:!0x2000                       ; encoding: [0x11,0x4f,0x00,0x20]
cmp A, ES:!0x2000

# CHECK-INST: cmp a, es:[hl]                          ; encoding: [0x11,0x4d]
cmp A, ES:[HL]

# CHECK-INST: cmp a, es:[hl+18]                       ; encoding: [0x11,0x4e,0x12]
cmp A, ES:[HL+0x12]



# CHECK-INST: cmp a, es:[hl+b]                        ; encoding: [0x11,0x61,0xc0]
cmp A, ES:[HL+B]

# CHECK-INST: cmp a, es:[hl+c]                        ; encoding: [0x11,0x61,0xc2]
cmp A, ES:[HL+C]


# CHECK-INST: cmp es:!0x2000, #18                     ; encoding: [0x11,0x40,0x00,0x20,0x12]
cmp ES:!0x2000, #0x12
