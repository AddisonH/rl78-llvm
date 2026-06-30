# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: xch a, x                                ; encoding: [0x08]
xch A, X

# CHECK-INST: xch a, c                                ; encoding: [0x61,0x8a]
xch A, C

# CHECK-INST: xch a, b                                ; encoding: [0x61,0x8b]
xch A, B

# CHECK-INST: xch a, e                                ; encoding: [0x61,0x8c]
xch A, E

# CHECK-INST: xch a, d                                ; encoding: [0x61,0x8d]
xch A, D

# CHECK-INST: xch a, l                                ; encoding: [0x61,0x8e]
xch A, L

# CHECK-INST: xch a, h                                ; encoding: [0x61,0x8f]
xch A, H


# CHECK-INST: xch a, 0xffe20                       ; encoding: [0x61,0xa8,0x20]
xch A, 0xFFE20

# CHECK-INST: xch a, saddr                            ; encoding: [0x61,0xa8,A]
xch A, saddr



# CHECK-INST: xch a, 0xfff20                          ; encoding: [0x61,0xab,0x20]
xch A, 0xFFF20



# CHECK-INST: xch a, !0xf2100                         ; encoding: [0x61,0xaa,0x00,0x21]
xch A, !0x2100

# CHECK-INST: xch a, [de]                             ; encoding: [0x61,0xae]
xch A, [DE]

# CHECK-INST: xch a, [de+16]                          ; encoding: [0x61,0xaf,0x10]
xch A, [DE+0x10]

# CHECK-INST: xch a, [hl]                             ; encoding: [0x61,0xac]
xch A, [HL]

# CHECK-INST: xch a, [hl+16]                          ; encoding: [0x61,0xad,0x10]
xch A, [HL+0x10]

# CHECK-INST: xch a, [hl+b]                           ; encoding: [0x61,0xb9]
xch A, [HL+B]

# CHECK-INST: xch a, [hl+c]                           ; encoding: [0x61,0xa9]
xch A, [HL+C]



# CHECK-INST: xch a, es:!0x2100                       ; encoding: [0x11,0x61,0xaa,0x00,0x21]
xch A, ES:!0x2100

# CHECK-INST: xch a, es:[de]                          ; encoding: [0x11,0x61,0xae]
xch A, ES:[DE]

# CHECK-INST: xch a, es:[de+16]                       ; encoding: [0x11,0x61,0xaf,0x10]
xch A, ES:[DE+0x10]

# CHECK-INST: xch a, es:[hl]                          ; encoding: [0x11,0x61,0xac]
xch A, ES:[HL]

# CHECK-INST: xch a, es:[hl+16]                       ; encoding: [0x11,0x61,0xad,0x10]
xch A, ES:[HL+0x10]

# CHECK-INST: xch a, es:[hl+b]                        ; encoding: [0x11,0x61,0xb9]
xch A, ES:[HL+B]

# CHECK-INST: xch a, es:[hl+c]                        ; encoding: [0x11,0x61,0xa9]
xch A, ES:[HL+C] 
