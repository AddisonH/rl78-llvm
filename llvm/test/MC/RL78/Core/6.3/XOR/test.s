# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: xor a, #18                              ; encoding: [0x7c,0x12]
xor A, #0x12


# CHECK-INST: xor 0xffe20, #18                     ; encoding: [0x7a,0x20,0x12]
xor 0xFFE20, #0x12

# CHECK-INST: xor saddr, #18                          ; encoding: [0x7a,A,0x12]
xor saddr, #0x12


# CHECK-INST: xor a, x                                ; encoding: [0x61,0x78]
xor A, X

# CHECK-INST: xor a, c                                ; encoding: [0x61,0x7a]
xor A, C

# CHECK-INST: xor a, b                                ; encoding: [0x61,0x7b]
xor A, B

# CHECK-INST: xor a, e                                ; encoding: [0x61,0x7c]
xor A, E

# CHECK-INST: xor a, d                                ; encoding: [0x61,0x7d]
xor A, D

# CHECK-INST: xor a, l                                ; encoding: [0x61,0x7e]
xor A, L

# CHECK-INST: xor a, h                                ; encoding: [0x61,0x7f]
xor A, H



# CHECK-INST: xor x, a                                ; encoding: [0x61,0x70]
xor X, A

# CHECK-INST: xor a, a                                ; encoding: [0x61,0x71]
xor A, A

# CHECK-INST: xor c, a                                ; encoding: [0x61,0x72]
xor C, A

# CHECK-INST: xor b, a                                ; encoding: [0x61,0x73]
xor B, A

# CHECK-INST: xor e, a                                ; encoding: [0x61,0x74]
xor E, A

# CHECK-INST: xor d, a                                ; encoding: [0x61,0x75]
xor D, A

# CHECK-INST: xor l, a                                ; encoding: [0x61,0x76]
xor L, A

# CHECK-INST: xor h, a                                ; encoding: [0x61,0x77]
xor H, A



# CHECK-INST: xor a, 0xffe20                       ; encoding: [0x7b,0x20]
xor A, 0xFFE20

# CHECK-INST: xor a, !0xf2000                         ; encoding: [0x7f,0x00,0x20]
xor A, !0x2000

# CHECK-INST: xor a, [hl]                             ; encoding: [0x7d]
xor A, [HL]

# CHECK-INST: xor a, [hl+18]                          ; encoding: [0x7e,0x12]
xor A, [HL+0x12]



# CHECK-INST: xor a, [hl+b]                           ; encoding: [0x61,0xf0]
xor A, [HL+B]

# CHECK-INST: xor a, [hl+c]                           ; encoding: [0x61,0xf2]
xor A, [HL+C]


# CHECK-INST: xor a, es:!0x2000                       ; encoding: [0x11,0x7f,0x00,0x20]
xor A, ES:!0x2000

# CHECK-INST: xor a, es:[hl]                          ; encoding: [0x11,0x7d]
xor A, ES:[HL]

# CHECK-INST: xor a, es:[hl+18]                       ; encoding: [0x11,0x7e,0x12]
xor A, ES:[HL+0x12]

# CHECK-INST: xor a, es:[hl+b]                        ; encoding: [0x11,0x61,0xf0]
xor A, ES:[HL+B]

# CHECK-INST: xor a, es:[hl+c]                        ; encoding: [0x11,0x61,0xf2]
xor A, ES:[HL+C]
