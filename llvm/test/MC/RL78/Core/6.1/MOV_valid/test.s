# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: mov x, #18                              ; encoding: [0x50,0x12]
mov X,   #0x12

# CHECK-INST: mov a, #18                              ; encoding: [0x51,0x12]
mov A,   #0x12

# CHECK-INST: mov c, #18                              ; encoding: [0x52,0x12]
mov C,   #0x12

# CHECK-INST: mov b, #18                              ; encoding: [0x53,0x12]
mov B,   #0x12

# CHECK-INST: mov e, #18                              ; encoding: [0x54,0x12]
mov E,   #0x12

# CHECK-INST: mov d, #18                              ; encoding: [0x55,0x12]
mov D,   #0x12

# CHECK-INST: mov l, #18                              ; encoding: [0x56,0x12]
mov L,   #0x12

# CHECK-INST: mov h, #18                              ; encoding: [0x57,0x12]
mov H,   #0x12


# CHECK-INST: mov saddr, #170                         ; encoding: [0xcd,A,0xaa]
mov   saddr, #0xAA

# CHECK-INST: mov 0xffe20, #170                    ; encoding: [0xcd,0x20,0xaa]
mov 0xFFE20, #0xAA


# CHECK-INST: mov 0xfff20, #170                        ; encoding: [0xce,0x20,0xaa]
mov 0xFFF20, #0xAA


# CHECK-INST: mov !0xf2000, #170                      ; encoding: [0xcf,0x00,0x20,0xaa]
mov !0x2000, #0xAA



# CHECK-INST: mov a, x                                ; encoding: [0x60]
mov A,   X

# CHECK-INST: mov a, c                                ; encoding: [0x62]
mov A,   C

# CHECK-INST: mov a, b                                ; encoding: [0x63]
mov A,   B

# CHECK-INST: mov a, e                                ; encoding: [0x64]
mov A,   E

# CHECK-INST: mov a, d                                ; encoding: [0x65]
mov A,   D

# CHECK-INST: mov a, l                                ; encoding: [0x66]
mov A,   L

# CHECK-INST: mov a, h                                ; encoding: [0x67]
mov A,   H


# CHECK-INST: mov x, a                                ; encoding: [0x70]
mov X,   A

# CHECK-INST: mov c, a                                ; encoding: [0x72]
mov C,   A

# CHECK-INST: mov b, a                                ; encoding: [0x73]
mov B,   A

# CHECK-INST: mov e, a                                ; encoding: [0x74]
mov E,   A

# CHECK-INST: mov d, a                                ; encoding: [0x75]
mov D,   A

# CHECK-INST: mov l, a                                ; encoding: [0x76]
mov L,   A

# CHECK-INST: mov h, a                                ; encoding: [0x77]
mov H,   A



# CHECK-INST: mov a, saddr                            ; encoding: [0x8d,A]
mov A, saddr

# CHECK-INST: mov a, 0xffe20                       ; encoding: [0x8d,0x20]
mov A,   0xFFE20


# CHECK-INST: mov saddr, a                             ; encoding: [0x9d,A]
mov saddr, A

# CHECK-INST: mov 0xffe20, a                       ; encoding: [0x9d,0x20]
mov 0xFFE20, A



# CHECK-INST: mov a, 0xfff20                          ; encoding: [0x8e,0x20]
mov A, 0xFFF20



# CHECK-INST: mov 0xfff20, a                          ; encoding: [0x9e,0x20]
mov 0xFFF20, A



# CHECK-INST: mov a, !0xf2100                         ; encoding: [0x8f,0x00,0x21]
mov A,   !0x2100

# CHECK-INST: mov !0xf2100, a                         ; encoding: [0x9f,0x00,0x21]
mov !0x2100, A



# CHECK-INST: mov psw, #6                             ; encoding: [0xce,0xfa,0x06]
mov PSW, #0x06

# CHECK-INST: mov psw, a                              ; encoding: [0x9e,0xfa]
mov PSW, A



# CHECK-INST: mov es, #0                              ; encoding: [0x41,0x00]
mov ES,  #0x00

# CHECK-INST: mov es, 0xffe20                      ; encoding: [0x61,0xb8,0x20]
mov ES, 0xFFE20

# CHECK-INST: mov a, es                               ; encoding: [0x8e,0xfd]
mov A,   ES

# CHECK-INST: mov es, a                               ; encoding: [0x9e,0xfd]
mov ES,  A



# CHECK-INST: mov cs, #1                              ; encoding: [0xce,0xfc,0x01]
mov CS,  #0x01

# CHECK-INST: mov a, cs                               ; encoding: [0x8e,0xfc]
mov A,   CS

# CHECK-INST: mov cs, a                               ; encoding: [0x9e,0xfc]
mov CS,  A



# CHECK-INST: mov a, [de]                             ; encoding: [0x89]
mov A, [DE]

# CHECK-INST: mov [de], a                             ; encoding: [0x99]
mov [DE], A

# CHECK-INST: mov [de+16], #18                        ; encoding: [0xca,0x10,0x12]
mov [DE+0x10], #0x12

# CHECK-INST: mov a, [de+18]                          ; encoding: [0x8a,0x12]
mov A, [DE+0x12]

# CHECK-INST: mov [de+18], a                          ; encoding: [0x9a,0x12]
mov [DE+0x12], A


# CHECK-INST: mov a, [hl]                             ; encoding: [0x8b]
mov A, [HL]

# CHECK-INST: mov [hl], a                             ; encoding: [0x9b]
mov [HL], A

# CHECK-INST: mov [hl+16], #18                        ; encoding: [0xcc,0x10,0x12]
mov [HL+0x10], #0x12

# CHECK-INST: mov a, [hl+18]                          ; encoding: [0x8c,0x12]
mov A, [HL+0x12]

# CHECK-INST: mov [hl+18], a                          ; encoding: [0x9c,0x12]
mov [HL+0x12], A



# CHECK-INST: mov a, [hl+b]                           ; encoding: [0x61,0xc9]
mov A, [HL+B]

# CHECK-INST: mov [hl+b], a                           ; encoding: [0x61,0xd9]
mov [HL+B], A

# CHECK-INST: mov a, [hl+c]                           ; encoding: [0x61,0xe9]
mov A, [HL+C]

# CHECK-INST: mov [hl+c], a                           ; encoding: [0x61,0xf9]
mov [HL+C], A



# CHECK-INST: mov word[b], #18                        ; encoding: [0x19,A,A,0x12]
mov word[B], #0x12

# CHECK-INST: mov a, word[b]                          ; encoding: [0x09,A,A]
mov A,   word[B]

# CHECK-INST: mov word[b], a                          ; encoding: [0x18,A,A]
mov word[B], A

# CHECK-INST: mov word[c], #18                        ; encoding: [0x38,A,A,0x12]
mov word[C], #0x12

# CHECK-INST: mov a, word[c]                          ; encoding: [0x29,A,A]
mov A,   word[C]

# CHECK-INST: mov word[c], a                          ; encoding: [0x28,A,A]
mov word[C], A

# CHECK-INST: mov word[bc], #18                       ; encoding: [0x39,A,A,0x12]
mov word[BC], #0x12

# CHECK-INST: mov a, word[bc]                         ; encoding: [0x49,A,A]
mov A,   word[BC]

# CHECK-INST: mov word[bc], a                         ; encoding: [0x48,A,A]
mov word[BC], A



# CHECK-INST: mov [sp+16], #18                        ; encoding: [0xc8,0x10,0x12]
mov [SP+0x10], #0x12

# CHECK-INST: mov a, [sp+18]                          ; encoding: [0x88,0x12]
mov A,   [SP+0x12]

# CHECK-INST: mov [sp+18], a                          ; encoding: [0x98,0x12]
mov [SP+0x12], A  



# CHECK-INST: mov b, 0xffe20                       ; encoding: [0xe8,0x20]
mov B,   0xFFE20

# CHECK-INST: mov b, !0xf2300                         ; encoding: [0xe9,0x00,0x23]
mov B,   !0x2300

# CHECK-INST: mov c, 0xffe20                       ; encoding: [0xf8,0x20]
mov C,   0xFFE20

# CHECK-INST: mov c, !0xf2302                         ; encoding: [0xf9,0x02,0x23]
mov C,   !0x2302

# CHECK-INST: mov x, 0xffe20                       ; encoding: [0xd8,0x20]
mov X,   0xFFE20

# CHECK-INST: mov x, !0xf2200                         ; encoding: [0xd9,0x00,0x22]
mov X,   !0x2200




# CHECK-INST: mov es:!0x2000, #170                    ; encoding: [0x11,0xcf,0x00,0x20,0xaa]
mov ES:!0x2000, #0xAA

# CHECK-INST: mov a, es:!0x2100                       ; encoding: [0x11,0x8f,0x00,0x21]
mov A,   ES:!0x2100

# CHECK-INST: mov es:!0x2100, a                       ; encoding: [0x11,0x9f,0x00,0x21]
mov ES:!0x2100, A

# CHECK-INST: mov a, es:[de]                          ; encoding: [0x11,0x89]
mov A, ES:[DE]

# CHECK-INST: mov es:[de], a                          ; encoding: [0x11,0x99]
mov ES:[DE], A

# CHECK-INST: mov es:[de+16], #18                     ; encoding: [0x11,0xca,0x10,0x12]
mov ES:[DE+0x10], #0x12

# CHECK-INST: mov a, es:[de+18]                       ; encoding: [0x11,0x8a,0x12]
mov A, ES:[DE+0x12]

# CHECK-INST: mov es:[de+18], a                       ; encoding: [0x11,0x9a,0x12]
mov ES:[DE+0x12], A

# CHECK-INST: mov a, es:[hl]                          ; encoding: [0x11,0x8b]
mov A, ES:[HL]

# CHECK-INST: mov es:[hl], a                          ; encoding: [0x11,0x9b]
mov ES:[HL], A

# CHECK-INST: mov es:[hl+16], #18                     ; encoding: [0x11,0xcc,0x10,0x12]
mov ES:[HL+0x10], #0x12

# CHECK-INST: mov a, es:[hl+18]                       ; encoding: [0x11,0x8c,0x12]
mov A, ES:[HL+0x12]

# CHECK-INST: mov es:[hl+18], a                       ; encoding: [0x11,0x9c,0x12]
mov ES:[HL+0x12], A

# CHECK-INST: mov a, es:[hl+b]                        ; encoding: [0x11,0x61,0xc9]
mov A, ES:[HL+B]

# CHECK-INST: mov es:[hl+b], a                        ; encoding: [0x11,0x61,0xd9]
mov ES:[HL+B], A

# CHECK-INST: mov a, es:[hl+c]                        ; encoding: [0x11,0x61,0xe9]
mov A, ES:[HL+C]

# CHECK-INST: mov es:[hl+c], a                        ; encoding: [0x11,0x61,0xf9]
mov ES:[HL+C], A

# CHECK-INST: mov es:word[b], #18                     ; encoding: [0x11,0x19,A,A,0x12]
mov ES:word[B], #0x12

# CHECK-INST: mov a, es:word[b]                       ; encoding: [0x11,0x09,A,A]
mov A,   ES:word[B]

# CHECK-INST: mov es:word[b], a                       ; encoding: [0x11,0x18,A,A]
mov ES:word[B], A

# CHECK-INST: mov es:word[c], #18                     ; encoding: [0x11,0x38,A,A,0x12]
mov ES:word[C], #0x12

# CHECK-INST: mov a, es:word[c]                       ; encoding: [0x11,0x29,A,A]
mov A,   ES:word[C]

# CHECK-INST: mov es:word[c], a                       ; encoding: [0x11,0x28,A,A]
mov ES:word[C], A

# CHECK-INST: mov es:word[bc], #18                    ; encoding: [0x11,0x39,A,A,0x12]
mov ES:word[BC], #0x12

# CHECK-INST: mov a, es:word[bc]                      ; encoding: [0x11,0x49,A,A]
mov A,   ES:word[BC]

# CHECK-INST: mov es:word[bc], a                      ; encoding: [0x11,0x48,A,A]
mov ES:word[BC], A



# CHECK-INST: mov b, es:!0x2300                       ; encoding: [0x11,0xe9,0x00,0x23]
mov B,   ES:!0x2300

# CHECK-INST: mov c, es:!0x2302                       ; encoding: [0x11,0xf9,0x02,0x23]
mov C,   ES:!0x2302

# CHECK-INST: mov x, es:!0x2200                       ; encoding: [0x11,0xd9,0x00,0x22]
mov X,   ES:!0x2200
