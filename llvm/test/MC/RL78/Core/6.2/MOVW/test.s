# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: movw ax, #4660                          ; encoding: [0x30,0x34,0x12]
movw AX, #0x1234

# CHECK-INST: movw bc, #22136                         ; encoding: [0x32,0x78,0x56]
movw BC, #0x5678

# CHECK-INST: movw de, #39612                         ; encoding: [0x34,0xbc,0x9a]
movw DE, #0x9ABC

# CHECK-INST: movw hl, #57072                         ; encoding: [0x36,0xf0,0xde]
movw HL, #0xDEF0



# CHECK-INST: movw saddrp, #8738                      ; encoding: [0xc9,A,0x22,0x22]
movw saddrp, #0x2222     ; saddrp, #word

# CHECK-INST: movw 0xffe20, #4369                     ; encoding: [0xc9,0x20,0x11,0x11]
movw 0xFFE20, #0x1111  ; saddrp, #word



# CHECK-INST: movw 0xfff20, #8738                     ; encoding: [0xcb,0x20,0x22,0x22]
movw 0xFFF20, #0x2222



# CHECK-INST: movw ax, 0xffe20                     ; encoding: [0xad,0x20]
movw AX, 0xFFE20              ; AX, saddrp

# CHECK-INST: movw ax, saddrp                         ; encoding: [0xad,A]
movw AX, saddrp               ; AX, saddrp



# CHECK-INST: movw 0xffe20, ax                     ; encoding: [0xbd,0x20]
movw 0xFFE20, AX              ; saddrp, AX

# CHECK-INST: movw saddrp, ax                          ; encoding: [0xbd,A]
movw saddrp, AX               ; saddrp, AX



# CHECK-INST: movw ax, 0xfff20                        ; encoding: [0xae,0x20]
movw AX, 0xFFF20               ; AX, sfrp



# CHECK-INST: movw 0xfff20, ax                        ; encoding: [0xbe,0x20]
movw 0xFFF20, AX               ; sfrp, AX



# CHECK-INST: movw ax, bc                             ; encoding: [0x13]
movw AX, BC             ; AX, rp

# CHECK-INST: movw ax, de                             ; encoding: [0x15]
movw AX, DE

# CHECK-INST: movw ax, hl                             ; encoding: [0x17]
movw AX, HL


# CHECK-INST: movw bc, ax                             ; encoding: [0x12]
movw BC, AX

# CHECK-INST: movw de, ax                             ; encoding: [0x14]
movw DE, AX

# CHECK-INST: movw hl, ax                             ; encoding: [0x16]
movw HL, AX



# CHECK-INST: movw ax, !0xf2000                       ; encoding: [0xaf,0x00,0x20]
movw AX, !0x2000        ; AX, !addr16

# CHECK-INST: movw !0xf2000, ax                       ; encoding: [0xbf,0x00,0x20]
movw !0x2000, AX        ; !addr16, AX]



# CHECK-INST: movw ax, [de]                           ; encoding: [0xa9]
movw AX, [DE]

# CHECK-INST: movw [de], ax                           ; encoding: [0xb9]
movw [DE], AX


# CHECK-INST: movw ax, [de+16]                        ; encoding: [0xaa,0x10]
movw AX, [DE+0x10]

# CHECK-INST: movw [de+16], ax                        ; encoding: [0xba,0x10]
movw [DE+0x10], AX

# CHECK-INST: movw ax, [hl]                           ; encoding: [0xab]
movw AX, [HL]

# CHECK-INST: movw [hl], ax                           ; encoding: [0xbb]
movw [HL], AX


# CHECK-INST: movw ax, [hl+16]                        ; encoding: [0xac,0x10]
movw AX, [HL+0x10]

# CHECK-INST: movw [hl+16], ax                        ; encoding: [0xbc,0x10]
movw [HL+0x10], AX




# CHECK-INST: movw ax, word[b]                        ; encoding: [0x59,A,A]
movw AX, word[B]

# CHECK-INST: movw word[b], ax                        ; encoding: [0x58,A,A]
movw word[B], AX



# CHECK-INST: movw ax, word[c]                        ; encoding: [0x69,A,A]
movw AX, word[C]

# CHECK-INST: movw word[c], ax                        ; encoding: [0x68,A,A]
movw word[C], AX


# CHECK-INST: movw ax, word[bc]                       ; encoding: [0x79,A,A]
movw AX, word[BC]

# CHECK-INST: movw word[bc], ax                       ; encoding: [0x78,A,A]
movw word[BC], AX


# CHECK-INST: movw ax, [sp+8]                         ; encoding: [0xa8,0x08]
movw AX, [SP+0x08]

# CHECK-INST: movw [sp+8], ax                         ; encoding: [0xb8,0x08]
movw [SP+0x08], AX

# CHECK-INST: movw bc, 0xffe20                     ; encoding: [0xda,0x20]
movw BC, 0xFFE20
# CHECK-INST: movw bc, !0xf2100                       ; encoding: [0xdb,0x00,0x21]
movw BC, !0x2100

# CHECK-INST: movw de, 0xffe20                     ; encoding: [0xea,0x20]
movw DE, 0xFFE20

# CHECK-INST: movw de, !0xf2200                       ; encoding: [0xeb,0x00,0x22]
movw DE, !0x2200

# CHECK-INST: movw hl, 0xffe20                     ; encoding: [0xfa,0x20]
movw HL, 0xFFE20

# CHECK-INST: movw hl, !0xf2300                       ; encoding: [0xfb,0x00,0x23]
movw HL, !0x2300



# CHECK-INST: movw ax, es:!0x2000                     ; encoding: [0x11,0xaf,0x00,0x20]
movw AX, ES:!0x2000     ; AX, ES:!addr16

# CHECK-INST: movw es:!0x2000, ax                     ; encoding: [0x11,0xbf,0x00,0x20]
movw ES:!0x2000, AX     ; ES:!addr16, ax


# CHECK-INST: movw ax, es:[de]                        ; encoding: [0x11,0xa9]
movw AX, ES:[DE]

# CHECK-INST: movw es:[de], ax                        ; encoding: [0x11,0xb9]
movw ES:[DE], AX



# CHECK-INST: movw ax, es:[de+16]                     ; encoding: [0x11,0xaa,0x10]
movw AX, ES:[DE+0x10]

# CHECK-INST: movw es:[de+16], ax                     ; encoding: [0x11,0xba,0x10]
movw ES:[DE+0x10], AX

# CHECK-INST: movw ax, es:[hl]                        ; encoding: [0x11,0xab]
movw AX, ES:[HL]

# CHECK-INST: movw es:[hl], ax                        ; encoding: [0x11,0xbb]
movw ES:[HL], AX

# CHECK-INST: movw ax, es:[hl+16]                     ; encoding: [0x11,0xac,0x10]
movw AX, ES:[HL+0x10]

# CHECK-INST: movw es:[hl+16], ax                     ; encoding: [0x11,0xbc,0x10]
movw ES:[HL+0x10], AX



# CHECK-INST: movw ax, es:word[b]                     ; encoding: [0x11,0x59,A,A]
movw AX, ES:word[B]

# CHECK-INST: movw es:word[b], ax                     ; encoding: [0x11,0x58,A,A
movw ES:word[B], AX

# CHECK-INST: movw ax, es:word[c]                     ; encoding: [0x11,0x69,A,A]
movw AX, ES:word[C]

# CHECK-INST: movw es:word[c], ax                     ; encoding: [0x11,0x68,A,A]
movw ES:word[C], AX

# CHECK-INST: movw ax, es:word[bc]                    ; encoding: [0x11,0x79,A,A]
movw AX, ES:word[BC]

# CHECK-INST: movw es:word[bc], ax                    ; encoding: [0x11,0x78,A,A]
movw ES:word[BC], AX



# CHECK-INST: movw bc, es:!0x2100                     ; encoding: [0x11,0xdb,0x00,0x21]
movw BC, ES:!0x2100

# CHECK-INST: movw de, es:!0x2200                     ; encoding: [0x11,0xeb,0x00,0x22]
movw DE, ES:!0x2200

# CHECK-INST: movw hl, es:!0x2300                     ; encoding: [0x11,0xfb,0x00,0x23]
movw HL, ES:!0x2300
