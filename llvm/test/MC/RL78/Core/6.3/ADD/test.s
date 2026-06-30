# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: add a, #18                              ; encoding: [0x0c,0x12]
add A, #0x12


# CHECK-INST: add 0xffe20, #18                     ; encoding: [0x0a,0x20,0x12]
add 0xFFE20, #0x12

# CHECK-INST: add saddr, #18                          ; encoding: [0x0a,A,0x12]
add saddr, #0x12



# CHECK-INST: add a, x                                ; encoding: [0x61,0x08]
add A, X

# CHECK-INST: add a, c                                ; encoding: [0x61,0x0a]
add A, C

# CHECK-INST: add a, b                                ; encoding: [0x61,0x0b]
add A, B

# CHECK-INST: add a, e                                ; encoding: [0x61,0x0c]
add A, E

# CHECK-INST: add a, d                                ; encoding: [0x61,0x0d]
add A, D

# CHECK-INST: add a, l                                ; encoding: [0x61,0x0e]
add A, L

# CHECK-INST: add a, h                                ; encoding: [0x61,0x0f]
add A, H


# CHECK-INST: add x, a                                ; encoding: [0x61,0x00]
add X, A

# CHECK-INST: add a, a                                ; encoding: [0x61,0x01]
add A, A

# CHECK-INST: add c, a                                ; encoding: [0x61,0x02]
add C, A

# CHECK-INST: add b, a                                ; encoding: [0x61,0x03]
add B, A

# CHECK-INST: add e, a                                ; encoding: [0x61,0x04]
add E, A

# CHECK-INST: add d, a                                ; encoding: [0x61,0x05]
add D, A

# CHECK-INST: add l, a                                ; encoding: [0x61,0x06]
add L, A

# CHECK-INST: add h, a                                ; encoding: [0x61,0x07]
add H, A



# CHECK-INST: add a, 0xffe20                       ; encoding: [0x0b,0x20]
add A, 0xFFE20

# CHECK-INST: add a, !0xf2000                         ; encoding: [0x0f,0x00,0x20]
add A, !0x2000

# CHECK-INST: add a, [hl]                             ; encoding: [0x0d]
add A, [HL]

# CHECK-INST: add a, [hl+18]                          ; encoding: [0x0e,0x12]
add A, [HL+0x12]

# CHECK-INST: add a, [hl+b]                           ; encoding: [0x61,0x80]
add A, [HL+B]

# CHECK-INST: add a, [hl+c]                           ; encoding: [0x61,0x82]
add A, [HL+C]



# CHECK-INST: add a, es:!0x2000                       ; encoding: [0x11,0x0f,0x00,0x20]
add A, ES:!0x2000

# CHECK-INST: add a, es:[hl]                          ; encoding: [0x11,0x0d]
add A, ES:[HL]

# CHECK-INST: add a, es:[hl+18]                       ; encoding: [0x11,0x0e,0x12]
add A, ES:[HL+0x12]



# CHECK-INST: add a, es:[hl+b]                        ; encoding: [0x11,0x61,0x80]
add A, ES:[HL+B]

# CHECK-INST: add a, es:[hl+c]                        ; encoding: [0x11,0x61,0x82]
add A, ES:[HL+C]
