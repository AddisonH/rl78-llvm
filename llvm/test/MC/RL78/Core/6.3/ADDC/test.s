# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: addc a, #18                             ; encoding: [0x1c,0x12]
addc A, #0x12


# CHECK-INST: addc 0xffe20, #18                    ; encoding: [0x1a,0x20,0x12]
addc 0xFFE20, #0x12

# CHECK-INST: addc saddr, #18                         ; encoding: [0x1a,A,0x12]
addc saddr, #0x12



# CHECK-INST: addc a, x                               ; encoding: [0x61,0x18]
addc A, X

# CHECK-INST: addc a, c                               ; encoding: [0x61,0x1a]
addc A, C

# CHECK-INST: addc a, b                               ; encoding: [0x61,0x1b]
addc A, B

# CHECK-INST: addc a, e                               ; encoding: [0x61,0x1c]
addc A, E

# CHECK-INST: addc a, d                               ; encoding: [0x61,0x1d]
addc A, D

# CHECK-INST: addc a, l                               ; encoding: [0x61,0x1e]
addc A, L

# CHECK-INST: addc a, h                               ; encoding: [0x61,0x1f
addc A, H


# CHECK-INST: addc x, a                               ; encoding: [0x61,0x10]
addc X, A

# CHECK-INST: addc a, a                               ; encoding: [0x61,0x11]
addc A, A

# CHECK-INST: addc c, a                               ; encoding: [0x61,0x12]
addc C, A

# CHECK-INST: addc b, a                               ; encoding: [0x61,0x13]
addc B, A

# CHECK-INST: addc e, a                               ; encoding: [0x61,0x14]
addc E, A

# CHECK-INST: addc d, a                               ; encoding: [0x61,0x15
addc D, A

# CHECK-INST: addc l, a                               ; encoding: [0x61,0x16]
addc L, A

# CHECK-INST: addc h, a                               ; encoding: [0x61,0x17]
addc H, A



# CHECK-INST: addc a, 0xffe20                      ; encoding: [0x1b,0x20]
addc A,  0xFFE20

# CHECK-INST: addc a, !0xf2000                        ; encoding: [0x1f,0x00,0x20]
addc A, !0x2000

# CHECK-INST: addc a, [hl]                            ; encoding: [0x1d]
addc A, [HL]

# CHECK-INST: addc a, [hl+18]                         ; encoding: [0x1e,0x12]
addc A, [HL+0x12]


# CHECK-INST: addc a, [hl+b]                          ; encoding: [0x61,0x90]
addc A, [HL+B]

# CHECK-INST: addc a, [hl+c]                          ; encoding: [0x61,0x92]
addc A, [HL+C]


# CHECK-INST: addc a, es:!0x2000                      ; encoding: [0x11,0x1f,0x00,0x20]
addc A, ES:!0x2000

# CHECK-INST: addc a, es:[hl]                         ; encoding: [0x11,0x1d]
addc A, ES:[HL]

# CHECK-INST: addc a, es:[hl+18]                      ; encoding: [0x11,0x1e,0x12]
addc A, ES:[HL+0x12]

# CHECK-INST: addc a, es:[hl+b]                       ; encoding: [0x11,0x61,0x90]
addc A, ES:[HL+B]

# CHECK-INST: addc a, es:[hl+c]                       ; encoding: [0x11,0x61,0x92]
addc A, ES:[HL+C]
