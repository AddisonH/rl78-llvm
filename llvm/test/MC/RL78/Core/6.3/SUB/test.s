# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: sub a, #18                              ; encoding: [0x2c,0x12]
sub A, #0x12


# CHECK-INST: sub 0xffe20, #18                     ; encoding: [0x2a,0x20,0x12]
sub 0xFFE20, #0x12

# CHECK-INST: sub saddr, #18                          ; encoding: [0x2a,A,0x12]
sub saddr, #0x12


# CHECK-INST: sub a, x                                ; encoding: [0x61,0x28]
sub A, X

# CHECK-INST: sub a, c                                ; encoding: [0x61,0x2a]
sub A, C

# CHECK-INST: sub a, b                                ; encoding: [0x61,0x2b]
sub A, B

# CHECK-INST: sub a, e                                ; encoding: [0x61,0x2c]
sub A, E

# CHECK-INST: sub a, d                                ; encoding: [0x61,0x2d]
sub A, D

# CHECK-INST: sub a, l                                ; encoding: [0x61,0x2e]
sub A, L

# CHECK-INST: sub a, h                                ; encoding: [0x61,0x2f]
sub A, H


# CHECK-INST: sub x, a                                ; encoding: [0x61,0x20]
sub X, A

# CHECK-INST: sub a, a                                ; encoding: [0x61,0x21]
sub A, A

# CHECK-INST: sub c, a                                ; encoding: [0x61,0x22]
sub C, A

# CHECK-INST: sub b, a                                ; encoding: [0x61,0x23]
sub B, A

# CHECK-INST: sub e, a                                ; encoding: [0x61,0x24]
sub E, A

# CHECK-INST: sub d, a                                ; encoding: [0x61,0x25]
sub D, A

# CHECK-INST: sub l, a                                ; encoding: [0x61,0x26]
sub L, A

# CHECK-INST: sub h, a                                ; encoding: [0x61,0x27]
sub H, A


# CHECK-INST: sub a, 0xffe20                       ; encoding: [0x2b,0x20]
sub A, 0xFFE20

# CHECK-INST: sub a, !0xf2000                         ; encoding: [0x2f,0x00,0x20]
sub A, !0x2000

# CHECK-INST: sub a, [hl]                             ; encoding: [0x2d]
sub A, [HL]

# CHECK-INST: sub a, [hl+18]                          ; encoding: [0x2e,0x12]
sub A, [HL+0x12]

# CHECK-INST: sub a, [hl+b]                           ; encoding: [0x61,0xa0]
sub A, [HL+B]

# CHECK-INST: sub a, [hl+c]                           ; encoding: [0x61,0xa2]
sub A, [HL+C]

# CHECK-INST: sub a, es:!0x2000                       ; encoding: [0x11,0x2f,0x00,0x20]
sub A, ES:!0x2000

# CHECK-INST: sub a, es:[hl]                          ; encoding: [0x11,0x2d]
sub A, ES:[HL]

# CHECK-INST: sub a, es:[hl+18]                       ; encoding: [0x11,0x2e,0x12]
sub A, ES:[HL+0x12]

# CHECK-INST: sub a, es:[hl+b]                        ; encoding: [0x11,0x61,0xa0]
sub A, ES:[HL+B]

# CHECK-INST: sub a, es:[hl+c]                        ; encoding: [0x11,0x61,0xa2]
sub A, ES:[HL+C]
