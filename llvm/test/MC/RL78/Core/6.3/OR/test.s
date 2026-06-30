# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: or a, #18                               ; encoding: [0x6c,0x12]
or A, #0x12


# CHECK-INST: or 0xffe20, #18                      ; encoding: [0x6a,0x20,0x12]
or 0xFFE20, #0x12

# CHECK-INST: or saddr, #18                           ; encoding: [0x6a,A,0x12]
or saddr, #0x12


# CHECK-INST: or a, x                                 ; encoding: [0x61,0x68]
or A, X

# CHECK-INST: or a, c                                 ; encoding: [0x61,0x6a]
or A, C

# CHECK-INST: or a, b                                 ; encoding: [0x61,0x6b]
or A, B

# CHECK-INST: or a, e                                 ; encoding: [0x61,0x6c]
or A, E

# CHECK-INST: or a, d                                 ; encoding: [0x61,0x6d]
or A, D

# CHECK-INST: or a, l                                 ; encoding: [0x61,0x6e]
or A, L

# CHECK-INST: or a, h                                 ; encoding: [0x61,0x6f]
or A, H



# CHECK-INST: or x, a                                 ; encoding: [0x61,0x60]
or X, A

# CHECK-INST: or a, a                                 ; encoding: [0x61,0x61]
or A, A

# CHECK-INST: or c, a                                 ; encoding: [0x61,0x62]
or C, A

# CHECK-INST: or b, a                                 ; encoding: [0x61,0x63]
or B, A

# CHECK-INST: or e, a                                 ; encoding: [0x61,0x64]
or E, A

# CHECK-INST: or d, a                                 ; encoding: [0x61,0x65]
or D, A

# CHECK-INST: or l, a                                 ; encoding: [0x61,0x66]
or L, A

# CHECK-INST: or h, a                                 ; encoding: [0x61,0x67]
or H, A



# CHECK-INST: or a, 0xffe20                        ; encoding: [0x6b,0x20]
or A, 0xFFE20

# CHECK-INST: or a, !0xf2000                          ; encoding: [0x6f,0x00,0x20]
or A, !0x2000

# CHECK-INST: or a, [hl]                              ; encoding: [0x6d]
or A, [HL]

# CHECK-INST: or a, [hl+18]                           ; encoding: [0x6e,0x12]
or A, [HL+0x12]



# CHECK-INST: or a, [hl+b]                            ; encoding: [0x61,0xe0]
or A, [HL+B]

# CHECK-INST: or a, [hl+c]                            ; encoding: [0x61,0xe2]
or A, [HL+C]



# CHECK-INST: or a, es:!0x2000                        ; encoding: [0x11,0x6f,0x00,0x20]
or A, ES:!0x2000

# CHECK-INST: or a, es:[hl]                           ; encoding: [0x11,0x6d]
or A, ES:[HL]

# CHECK-INST: or a, es:[hl+18]                        ; encoding: [0x11,0x6e,0x12]
or A, ES:[HL+0x12]

# CHECK-INST: or a, es:[hl+b]                         ; encoding: [0x11,0x61,0xe0]
or A, ES:[HL+B]

# CHECK-INST: or a, es:[hl+c]                         ; encoding: [0x11,0x61,0xe2]
or A, ES:[HL+C]
