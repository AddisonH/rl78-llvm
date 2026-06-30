# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: subc a, #18                             ; encoding: [0x3c,0x12]
subc A, #0x12


# CHECK-INST: subc 0xffe20, #18                    ; encoding: [0x3a,0x20,0x12]
subc 0xFFE20, #0x12

# CHECK-INST: subc saddr, #18                         ; encoding: [0x3a,A,0x12]
subc saddr, #0x12


# CHECK-INST: subc a, x                               ; encoding: [0x61,0x38]
subc A, X

# CHECK-INST: subc a, c                               ; encoding: [0x61,0x3a]
subc A, C

# CHECK-INST: subc a, b                               ; encoding: [0x61,0x3b]
subc A, B

# CHECK-INST: subc a, e                               ; encoding: [0x61,0x3c]
subc A, E

# CHECK-INST: subc a, d                               ; encoding: [0x61,0x3d]
subc A, D

# CHECK-INST: subc a, l                               ; encoding: [0x61,0x3e]
subc A, L

# CHECK-INST: subc a, h                               ; encoding: [0x61,0x3f]
subc A, H


# CHECK-INST: subc x, a                               ; encoding: [0x61,0x30]
subc X, A

# CHECK-INST: subc a, a                               ; encoding: [0x61,0x31]
subc A, A

# CHECK-INST: subc c, a                               ; encoding: [0x61,0x32]
subc C, A

# CHECK-INST: subc b, a                               ; encoding: [0x61,0x33]
subc B, A

# CHECK-INST: subc e, a                               ; encoding: [0x61,0x34]
subc E, A

# CHECK-INST: subc d, a                               ; encoding: [0x61,0x35]
subc D, A

# CHECK-INST: subc l, a                               ; encoding: [0x61,0x36]
subc L, A

# CHECK-INST: subc h, a                               ; encoding: [0x61,0x37]
subc H, A



# CHECK-INST: subc a, 0xffe20                      ; encoding: [0x3b,0x20]
subc A, 0xFFE20

# CHECK-INST: subc a, !0xf2000                        ; encoding: [0x3f,0x00,0x20]
subc A, !0x2000

# CHECK-INST: subc a, [hl]                            ; encoding: [0x3d]
subc A, [HL]

# CHECK-INST: subc a, [hl+18]                         ; encoding: [0x3e,0x12]
subc A, [HL+0x12]



# CHECK-INST: subc a, [hl+b]                          ; encoding: [0x61,0xb0]
subc A, [HL+B]

# CHECK-INST: subc a, [hl+c]                          ; encoding: [0x61,0xb2]
subc A, [HL+C]



# CHECK-INST: subc a, es:!0x2000                      ; encoding: [0x11,0x3f,0x00,0x20]
subc A, ES:!0x2000

# CHECK-INST: subc a, es:[hl]                         ; encoding: [0x11,0x3d]
subc A, ES:[HL]

# CHECK-INST: subc a, es:[hl+18]                      ; encoding: [0x11,0x3e,0x12]
subc A, ES:[HL+0x12]



# CHECK-INST: subc a, es:[hl+b]                       ; encoding: [0x11,0x61,0xb0]
subc A, ES:[HL+B]

# CHECK-INST: subc a, es:[hl+c]                       ; encoding: [0x11,0x61,0xb2]
subc A, ES:[HL+C]
