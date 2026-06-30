# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: inc x                                   ; encoding: [0x80]
inc X

# CHECK-INST: inc a                                   ; encoding: [0x81]
inc A

# CHECK-INST: inc c                                   ; encoding: [0x82]
inc C

# CHECK-INST: inc b                                   ; encoding: [0x83]
inc B

# CHECK-INST: inc e                                   ; encoding: [0x84]
inc E

# CHECK-INST: inc d                                   ; encoding: [0x85]
inc D

# CHECK-INST: inc l                                   ; encoding: [0x86]
inc L

# CHECK-INST: inc h                                   ; encoding: [0x87]
inc H



# CHECK-INST: inc 0xffe20                          ; encoding: [0xa4,0x20]
inc 0xFFE20

# CHECK-INST: inc saddr                               ; encoding: [0xa4,A]
inc saddr


# CHECK-INST: inc !0xf2000                            ; encoding: [0xa0,0x00,0x20]
inc !0x2000

# CHECK-INST: inc [hl+18]                             ; encoding: [0x61,0x59,0x12]
inc [HL + 0x12]

# CHECK-INST: inc es:!0x2000                          ; encoding: [0x11,0xa0,0x00,0x20]
inc ES:!0x2000

# CHECK-INST: inc es:[hl+18]                          ; encoding: [0x11,0x61,0x59,0x12]
inc ES:[HL + 0x12]
