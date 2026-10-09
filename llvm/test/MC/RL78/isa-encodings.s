# Every encoding of the RL78 Family User's Manual: Software (R01US0015),
# operation list, with the bytes the manual gives.
# RUN: llvm-mc -triple=rl78 -show-encoding %s | FileCheck %s

# MOV X, #byte: 50 data
# CHECK: mov x, #18
# CHECK-SAME: encoding: [0x50,0x12]
mov x, #0x12

# MOV A, #byte: 51 data
# CHECK: mov a, #18
# CHECK-SAME: encoding: [0x51,0x12]
mov a, #0x12

# MOV C, #byte: 52 data
# CHECK: mov c, #18
# CHECK-SAME: encoding: [0x52,0x12]
mov c, #0x12

# MOV B, #byte: 53 data
# CHECK: mov b, #18
# CHECK-SAME: encoding: [0x53,0x12]
mov b, #0x12

# MOV E, #byte: 54 data
# CHECK: mov e, #18
# CHECK-SAME: encoding: [0x54,0x12]
mov e, #0x12

# MOV D, #byte: 55 data
# CHECK: mov d, #18
# CHECK-SAME: encoding: [0x55,0x12]
mov d, #0x12

# MOV L, #byte: 56 data
# CHECK: mov l, #18
# CHECK-SAME: encoding: [0x56,0x12]
mov l, #0x12

# MOV H, #byte: 57 data
# CHECK: mov h, #18
# CHECK-SAME: encoding: [0x57,0x12]
mov h, #0x12

# MOV saddr, #byte: CD saddr data
# CHECK: mov 0xffe80, #18
# CHECK-SAME: encoding: [0xcd,0x80,0x12]
mov 0xffe80, #0x12

# MOV sfr, #byte: CE sfr data
# CHECK: mov 0xfff30, #18
# CHECK-SAME: encoding: [0xce,0x30,0x12]
mov 0xfff30, #0x12

# MOV !addr16, #byte: CF adrl adrh data
# CHECK: mov !0xf1234, #18
# CHECK-SAME: encoding: [0xcf,0x34,0x12,0x12]
mov !0x1234, #0x12

# MOV A, X: 60
# CHECK: mov a, x
# CHECK-SAME: encoding: [0x60]
mov a, x

# MOV A, C: 62
# CHECK: mov a, c
# CHECK-SAME: encoding: [0x62]
mov a, c

# MOV A, B: 63
# CHECK: mov a, b
# CHECK-SAME: encoding: [0x63]
mov a, b

# MOV A, E: 64
# CHECK: mov a, e
# CHECK-SAME: encoding: [0x64]
mov a, e

# MOV A, D: 65
# CHECK: mov a, d
# CHECK-SAME: encoding: [0x65]
mov a, d

# MOV A, L: 66
# CHECK: mov a, l
# CHECK-SAME: encoding: [0x66]
mov a, l

# MOV A, H: 67
# CHECK: mov a, h
# CHECK-SAME: encoding: [0x67]
mov a, h

# MOV X, A: 70
# CHECK: mov x, a
# CHECK-SAME: encoding: [0x70]
mov x, a

# MOV C, A: 72
# CHECK: mov c, a
# CHECK-SAME: encoding: [0x72]
mov c, a

# MOV B, A: 73
# CHECK: mov b, a
# CHECK-SAME: encoding: [0x73]
mov b, a

# MOV E, A: 74
# CHECK: mov e, a
# CHECK-SAME: encoding: [0x74]
mov e, a

# MOV D, A: 75
# CHECK: mov d, a
# CHECK-SAME: encoding: [0x75]
mov d, a

# MOV L, A: 76
# CHECK: mov l, a
# CHECK-SAME: encoding: [0x76]
mov l, a

# MOV H, A: 77
# CHECK: mov h, a
# CHECK-SAME: encoding: [0x77]
mov h, a

# MOV A, saddr: 8D saddr
# CHECK: mov a, 0xffe80
# CHECK-SAME: encoding: [0x8d,0x80]
mov a, 0xffe80

# MOV saddr, A: 9D saddr
# CHECK: mov 0xffe80, a
# CHECK-SAME: encoding: [0x9d,0x80]
mov 0xffe80, a

# MOV A, sfr: 8E sfr
# CHECK: mov a, 0xfff30
# CHECK-SAME: encoding: [0x8e,0x30]
mov a, 0xfff30

# MOV sfr, A: 9E sfr
# CHECK: mov 0xfff30, a
# CHECK-SAME: encoding: [0x9e,0x30]
mov 0xfff30, a

# MOV A, !addr16: 8F adrl adrh
# CHECK: mov a, !0xf1234
# CHECK-SAME: encoding: [0x8f,0x34,0x12]
mov a, !0x1234

# MOV !addr16, A: 9F adrl adrh
# CHECK: mov !0xf1234, a
# CHECK-SAME: encoding: [0x9f,0x34,0x12]
mov !0x1234, a

# MOV PSW, #byte: CE FA data
# CHECK: mov psw, #18
# CHECK-SAME: encoding: [0xce,0xfa,0x12]
mov psw, #0x12

# MOV A, PSW: 8E FA
# CHECK: mov a, psw
# CHECK-SAME: encoding: [0x8e,0xfa]
mov a, psw

# MOV PSW, A: 9E FA
# CHECK: mov psw, a
# CHECK-SAME: encoding: [0x9e,0xfa]
mov psw, a

# MOV ES, #byte: 41 data
# CHECK: mov es, #18
# CHECK-SAME: encoding: [0x41,0x12]
mov es, #0x12

# MOV ES, saddr: 61 B8 saddr
# CHECK: mov es, 0xffe80
# CHECK-SAME: encoding: [0x61,0xb8,0x80]
mov es, 0xffe80

# MOV A, ES: 8E FD
# CHECK: mov a, es
# CHECK-SAME: encoding: [0x8e,0xfd]
mov a, es

# MOV ES, A: 9E FD
# CHECK: mov es, a
# CHECK-SAME: encoding: [0x9e,0xfd]
mov es, a

# MOV CS, #byte: CE FC data
# CHECK: mov cs, #18
# CHECK-SAME: encoding: [0xce,0xfc,0x12]
mov cs, #0x12

# MOV A, CS: 8E FC
# CHECK: mov a, cs
# CHECK-SAME: encoding: [0x8e,0xfc]
mov a, cs

# MOV CS, A: 9E FC
# CHECK: mov cs, a
# CHECK-SAME: encoding: [0x9e,0xfc]
mov cs, a

# MOV A, [DE]: 89
# CHECK: mov a, [de]
# CHECK-SAME: encoding: [0x89]
mov a, [de]

# MOV [DE], A: 99
# CHECK: mov [de], a
# CHECK-SAME: encoding: [0x99]
mov [de], a

# MOV [DE+byte], #byte: CA adr data
# CHECK: mov [de+5], #18
# CHECK-SAME: encoding: [0xca,0x05,0x12]
mov [de+0x5], #0x12

# MOV A, [DE+byte]: 8A adr
# CHECK: mov a, [de+5]
# CHECK-SAME: encoding: [0x8a,0x05]
mov a, [de+0x5]

# MOV [DE+byte], A: 9A adr
# CHECK: mov [de+5], a
# CHECK-SAME: encoding: [0x9a,0x05]
mov [de+0x5], a

# MOV A, [HL]: 8B
# CHECK: mov a, [hl]
# CHECK-SAME: encoding: [0x8b]
mov a, [hl]

# MOV [HL], A: 9B
# CHECK: mov [hl], a
# CHECK-SAME: encoding: [0x9b]
mov [hl], a

# MOV [HL+byte], #byte: CC adr data
# CHECK: mov [hl+5], #18
# CHECK-SAME: encoding: [0xcc,0x05,0x12]
mov [hl+0x5], #0x12

# MOV A, [HL+byte]: 8C adr
# CHECK: mov a, [hl+5]
# CHECK-SAME: encoding: [0x8c,0x05]
mov a, [hl+0x5]

# MOV [HL+byte], A: 9C adr
# CHECK: mov [hl+5], a
# CHECK-SAME: encoding: [0x9c,0x05]
mov [hl+0x5], a

# MOV A, [HL+B]: 61 C9
# CHECK: mov a, [hl+b]
# CHECK-SAME: encoding: [0x61,0xc9]
mov a, [hl+b]

# MOV [HL+B], A: 61 D9
# CHECK: mov [hl+b], a
# CHECK-SAME: encoding: [0x61,0xd9]
mov [hl+b], a

# MOV A, [HL+C]: 61 E9
# CHECK: mov a, [hl+c]
# CHECK-SAME: encoding: [0x61,0xe9]
mov a, [hl+c]

# MOV [HL+C], A: 61 F9
# CHECK: mov [hl+c], a
# CHECK-SAME: encoding: [0x61,0xf9]
mov [hl+c], a

# MOV word[B], #byte: 19 adrl adrh data
# CHECK: mov 4660[b], #18
# CHECK-SAME: encoding: [0x19,0x34,0x12,0x12]
mov 0x1234[b], #0x12

# MOV A, word[B]: 09 adrl adrh
# CHECK: mov a, 4660[b]
# CHECK-SAME: encoding: [0x09,0x34,0x12]
mov a, 0x1234[b]

# MOV word[B], A: 18 adrl adrh
# CHECK: mov 4660[b], a
# CHECK-SAME: encoding: [0x18,0x34,0x12]
mov 0x1234[b], a

# MOV word[C], #byte: 38 adrl adrh data
# CHECK: mov 4660[c], #18
# CHECK-SAME: encoding: [0x38,0x34,0x12,0x12]
mov 0x1234[c], #0x12

# MOV A, word[C]: 29 adrl adrh
# CHECK: mov a, 4660[c]
# CHECK-SAME: encoding: [0x29,0x34,0x12]
mov a, 0x1234[c]

# MOV word[C], A: 28 adrl adrh
# CHECK: mov 4660[c], a
# CHECK-SAME: encoding: [0x28,0x34,0x12]
mov 0x1234[c], a

# MOV word[BC], #byte: 39 adrl adrh data
# CHECK: mov 4660[bc], #18
# CHECK-SAME: encoding: [0x39,0x34,0x12,0x12]
mov 0x1234[bc], #0x12

# MOV A, word[BC]: 49 adrl adrh
# CHECK: mov a, 4660[bc]
# CHECK-SAME: encoding: [0x49,0x34,0x12]
mov a, 0x1234[bc]

# MOV word[BC], A: 48 adrl adrh
# CHECK: mov 4660[bc], a
# CHECK-SAME: encoding: [0x48,0x34,0x12]
mov 0x1234[bc], a

# MOV [SP+byte], #byte: C8 adr data
# CHECK: mov [sp+5], #18
# CHECK-SAME: encoding: [0xc8,0x05,0x12]
mov [sp+0x5], #0x12

# MOV A, [SP+byte]: 88 adr
# CHECK: mov a, [sp+5]
# CHECK-SAME: encoding: [0x88,0x05]
mov a, [sp+0x5]

# MOV [SP+byte], A: 98 adr
# CHECK: mov [sp+5], a
# CHECK-SAME: encoding: [0x98,0x05]
mov [sp+0x5], a

# MOV B, saddr: E8 saddr
# CHECK: mov b, 0xffe80
# CHECK-SAME: encoding: [0xe8,0x80]
mov b, 0xffe80

# MOV B, !addr16: E9 adrl adrh
# CHECK: mov b, !0xf1234
# CHECK-SAME: encoding: [0xe9,0x34,0x12]
mov b, !0x1234

# MOV C, saddr: F8 saddr
# CHECK: mov c, 0xffe80
# CHECK-SAME: encoding: [0xf8,0x80]
mov c, 0xffe80

# MOV C, !addr16: F9 adrl adrh
# CHECK: mov c, !0xf1234
# CHECK-SAME: encoding: [0xf9,0x34,0x12]
mov c, !0x1234

# MOV X, saddr: D8 saddr
# CHECK: mov x, 0xffe80
# CHECK-SAME: encoding: [0xd8,0x80]
mov x, 0xffe80

# MOV X, !addr16: D9 adrl adrh
# CHECK: mov x, !0xf1234
# CHECK-SAME: encoding: [0xd9,0x34,0x12]
mov x, !0x1234

# MOV ES:!addr16, #byte: 11 CF adrl adrh data
# CHECK: mov es:!0x1234, #18
# CHECK-SAME: encoding: [0x11,0xcf,0x34,0x12,0x12]
mov es:!0x1234, #0x12

# MOV A, ES:!addr16: 11 8F adrl adrh
# CHECK: mov a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x8f,0x34,0x12]
mov a, es:!0x1234

# MOV ES:!addr16, A: 11 9F adrl adrh
# CHECK: mov es:!0x1234, a
# CHECK-SAME: encoding: [0x11,0x9f,0x34,0x12]
mov es:!0x1234, a

# MOV A, ES:[DE]: 11 89
# CHECK: mov a, es:[de]
# CHECK-SAME: encoding: [0x11,0x89]
mov a, es:[de]

# MOV ES:[DE], A: 11 99
# CHECK: mov es:[de], a
# CHECK-SAME: encoding: [0x11,0x99]
mov es:[de], a

# MOV ES:[DE+byte], #byte: 11 CA adr data
# CHECK: mov es:[de+5], #18
# CHECK-SAME: encoding: [0x11,0xca,0x05,0x12]
mov es:[de+0x5], #0x12

# MOV A, ES:[DE+byte]: 11 8A adr
# CHECK: mov a, es:[de+5]
# CHECK-SAME: encoding: [0x11,0x8a,0x05]
mov a, es:[de+0x5]

# MOV ES:[DE+byte], A: 11 9A adr
# CHECK: mov es:[de+5], a
# CHECK-SAME: encoding: [0x11,0x9a,0x05]
mov es:[de+0x5], a

# MOV A, ES:[HL]: 11 8B
# CHECK: mov a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x8b]
mov a, es:[hl]

# MOV ES:[HL], A: 11 9B
# CHECK: mov es:[hl], a
# CHECK-SAME: encoding: [0x11,0x9b]
mov es:[hl], a

# MOV ES:[HL+byte], #byte: 11 CC adr data
# CHECK: mov es:[hl+5], #18
# CHECK-SAME: encoding: [0x11,0xcc,0x05,0x12]
mov es:[hl+0x5], #0x12

# MOV A, ES:[HL+byte]: 11 8C adr
# CHECK: mov a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x8c,0x05]
mov a, es:[hl+0x5]

# MOV ES:[HL+byte], A: 11 9C adr
# CHECK: mov es:[hl+5], a
# CHECK-SAME: encoding: [0x11,0x9c,0x05]
mov es:[hl+0x5], a

# MOV A, ES:[HL+B]: 11 61 C9
# CHECK: mov a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0xc9]
mov a, es:[hl+b]

# MOV ES:[HL+B], A: 11 61 D9
# CHECK: mov es:[hl+b], a
# CHECK-SAME: encoding: [0x11,0x61,0xd9]
mov es:[hl+b], a

# MOV A, ES:[HL+C]: 11 61 E9
# CHECK: mov a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0xe9]
mov a, es:[hl+c]

# MOV ES:[HL+C], A: 11 61 F9
# CHECK: mov es:[hl+c], a
# CHECK-SAME: encoding: [0x11,0x61,0xf9]
mov es:[hl+c], a

# MOV ES:word[B], #byte: 11 19 adrl adrh data
# CHECK: mov es:4660[b], #18
# CHECK-SAME: encoding: [0x11,0x19,0x34,0x12,0x12]
mov es:0x1234[b], #0x12

# MOV A, ES:word[B]: 11 09 adrl adrh
# CHECK: mov a, es:4660[b]
# CHECK-SAME: encoding: [0x11,0x09,0x34,0x12]
mov a, es:0x1234[b]

# MOV ES:word[B], A: 11 18 adrl adrh
# CHECK: mov es:4660[b], a
# CHECK-SAME: encoding: [0x11,0x18,0x34,0x12]
mov es:0x1234[b], a

# MOV ES:word[C], #byte: 11 38 adrl adrh data
# CHECK: mov es:4660[c], #18
# CHECK-SAME: encoding: [0x11,0x38,0x34,0x12,0x12]
mov es:0x1234[c], #0x12

# MOV A, ES:word[C]: 11 29 adrl adrh
# CHECK: mov a, es:4660[c]
# CHECK-SAME: encoding: [0x11,0x29,0x34,0x12]
mov a, es:0x1234[c]

# MOV ES:word[C], A: 11 28 adrl adrh
# CHECK: mov es:4660[c], a
# CHECK-SAME: encoding: [0x11,0x28,0x34,0x12]
mov es:0x1234[c], a

# MOV ES:word[BC], #byte: 11 39 adrl adrh data
# CHECK: mov es:4660[bc], #18
# CHECK-SAME: encoding: [0x11,0x39,0x34,0x12,0x12]
mov es:0x1234[bc], #0x12

# MOV A, ES:word[BC]: 11 49 adrl adrh
# CHECK: mov a, es:4660[bc]
# CHECK-SAME: encoding: [0x11,0x49,0x34,0x12]
mov a, es:0x1234[bc]

# MOV ES:word[BC], A: 11 48 adrl adrh
# CHECK: mov es:4660[bc], a
# CHECK-SAME: encoding: [0x11,0x48,0x34,0x12]
mov es:0x1234[bc], a

# MOV B, ES:!addr16: 11 E9 adrl adrh
# CHECK: mov b, es:!0x1234
# CHECK-SAME: encoding: [0x11,0xe9,0x34,0x12]
mov b, es:!0x1234

# MOV C, ES:!addr16: 11 F9 adrl adrh
# CHECK: mov c, es:!0x1234
# CHECK-SAME: encoding: [0x11,0xf9,0x34,0x12]
mov c, es:!0x1234

# MOV X, ES:!addr16: 11 D9 adrl adrh
# CHECK: mov x, es:!0x1234
# CHECK-SAME: encoding: [0x11,0xd9,0x34,0x12]
mov x, es:!0x1234

# XCH A, X: 08
# CHECK: xch a, x
# CHECK-SAME: encoding: [0x08]
xch a, x

# XCH A, C: 61 8A
# CHECK: xch a, c
# CHECK-SAME: encoding: [0x61,0x8a]
xch a, c

# XCH A, B: 61 8B
# CHECK: xch a, b
# CHECK-SAME: encoding: [0x61,0x8b]
xch a, b

# XCH A, E: 61 8C
# CHECK: xch a, e
# CHECK-SAME: encoding: [0x61,0x8c]
xch a, e

# XCH A, D: 61 8D
# CHECK: xch a, d
# CHECK-SAME: encoding: [0x61,0x8d]
xch a, d

# XCH A, L: 61 8E
# CHECK: xch a, l
# CHECK-SAME: encoding: [0x61,0x8e]
xch a, l

# XCH A, H: 61 8F
# CHECK: xch a, h
# CHECK-SAME: encoding: [0x61,0x8f]
xch a, h

# XCH A, saddr: 61 A8 saddr
# CHECK: xch a, 0xffe80
# CHECK-SAME: encoding: [0x61,0xa8,0x80]
xch a, 0xffe80

# XCH A, sfr: 61 AB sfr
# CHECK: xch a, 0xfff30
# CHECK-SAME: encoding: [0x61,0xab,0x30]
xch a, 0xfff30

# XCH A, !addr16: 61 AA adrl adrh
# CHECK: xch a, !0xf1234
# CHECK-SAME: encoding: [0x61,0xaa,0x34,0x12]
xch a, !0x1234

# XCH A, [DE]: 61 AE
# CHECK: xch a, [de]
# CHECK-SAME: encoding: [0x61,0xae]
xch a, [de]

# XCH A, [DE+byte]: 61 AF adr
# CHECK: xch a, [de+5]
# CHECK-SAME: encoding: [0x61,0xaf,0x05]
xch a, [de+0x5]

# XCH A, [HL]: 61 AC
# CHECK: xch a, [hl]
# CHECK-SAME: encoding: [0x61,0xac]
xch a, [hl]

# XCH A, [HL+byte]: 61 AD adr
# CHECK: xch a, [hl+5]
# CHECK-SAME: encoding: [0x61,0xad,0x05]
xch a, [hl+0x5]

# XCH A, [HL+B]: 61 B9
# CHECK: xch a, [hl+b]
# CHECK-SAME: encoding: [0x61,0xb9]
xch a, [hl+b]

# XCH A, [HL+C]: 61 A9
# CHECK: xch a, [hl+c]
# CHECK-SAME: encoding: [0x61,0xa9]
xch a, [hl+c]

# XCH A, ES:!addr16: 11 61 AA adrl adrh
# CHECK: xch a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x61,0xaa,0x34,0x12]
xch a, es:!0x1234

# XCH A, ES:[DE]: 11 61 AE
# CHECK: xch a, es:[de]
# CHECK-SAME: encoding: [0x11,0x61,0xae]
xch a, es:[de]

# XCH A, ES:[DE+byte]: 11 61 AF adr
# CHECK: xch a, es:[de+5]
# CHECK-SAME: encoding: [0x11,0x61,0xaf,0x05]
xch a, es:[de+0x5]

# XCH A, ES:[HL]: 11 61 AC
# CHECK: xch a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x61,0xac]
xch a, es:[hl]

# XCH A, ES:[HL+byte]: 11 61 AD adr
# CHECK: xch a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x61,0xad,0x05]
xch a, es:[hl+0x5]

# XCH A, ES:[HL+B]: 11 61 B9
# CHECK: xch a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0xb9]
xch a, es:[hl+b]

# XCH A, ES:[HL+C]: 11 61 A9
# CHECK: xch a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0xa9]
xch a, es:[hl+c]

# ONEB A: E1
# CHECK: oneb a
# CHECK-SAME: encoding: [0xe1]
oneb a

# ONEB X: E0
# CHECK: oneb x
# CHECK-SAME: encoding: [0xe0]
oneb x

# ONEB B: E3
# CHECK: oneb b
# CHECK-SAME: encoding: [0xe3]
oneb b

# ONEB C: E2
# CHECK: oneb c
# CHECK-SAME: encoding: [0xe2]
oneb c

# ONEB saddr: E4 saddr
# CHECK: oneb 0xffe80
# CHECK-SAME: encoding: [0xe4,0x80]
oneb 0xffe80

# ONEB !addr16: E5 adrl adrh
# CHECK: oneb !0xf1234
# CHECK-SAME: encoding: [0xe5,0x34,0x12]
oneb !0x1234

# ONEB ES:!addr16: 11 E5 adrl adrh
# CHECK: oneb es:!0x1234
# CHECK-SAME: encoding: [0x11,0xe5,0x34,0x12]
oneb es:!0x1234

# CLRB A: F1
# CHECK: clrb a
# CHECK-SAME: encoding: [0xf1]
clrb a

# CLRB X: F0
# CHECK: clrb x
# CHECK-SAME: encoding: [0xf0]
clrb x

# CLRB B: F3
# CHECK: clrb b
# CHECK-SAME: encoding: [0xf3]
clrb b

# CLRB C: F2
# CHECK: clrb c
# CHECK-SAME: encoding: [0xf2]
clrb c

# CLRB saddr: F4 saddr
# CHECK: clrb 0xffe80
# CHECK-SAME: encoding: [0xf4,0x80]
clrb 0xffe80

# CLRB !addr16: F5 adrl adrh
# CHECK: clrb !0xf1234
# CHECK-SAME: encoding: [0xf5,0x34,0x12]
clrb !0x1234

# CLRB ES:!addr16: 11 F5 adrl adrh
# CHECK: clrb es:!0x1234
# CHECK-SAME: encoding: [0x11,0xf5,0x34,0x12]
clrb es:!0x1234

# MOVS [HL+byte], X: 61 CE adr
# CHECK: movs [hl+5], x
# CHECK-SAME: encoding: [0x61,0xce,0x05]
movs [hl+0x5], x

# MOVS ES:[HL+byte], X: 11 61 CE adr
# CHECK: movs es:[hl+5], x
# CHECK-SAME: encoding: [0x11,0x61,0xce,0x05]
movs es:[hl+0x5], x

# MOVW AX, #word: 30 datal datah
# CHECK: movw ax, #13398
# CHECK-SAME: encoding: [0x30,0x56,0x34]
movw ax, #0x3456

# MOVW BC, #word: 32 datal datah
# CHECK: movw bc, #13398
# CHECK-SAME: encoding: [0x32,0x56,0x34]
movw bc, #0x3456

# MOVW DE, #word: 34 datal datah
# CHECK: movw de, #13398
# CHECK-SAME: encoding: [0x34,0x56,0x34]
movw de, #0x3456

# MOVW HL, #word: 36 datal datah
# CHECK: movw hl, #13398
# CHECK-SAME: encoding: [0x36,0x56,0x34]
movw hl, #0x3456

# MOVW saddrp, #word: C9 saddr datal datah
# CHECK: movw 0xffe80, #13398
# CHECK-SAME: encoding: [0xc9,0x80,0x56,0x34]
movw 0xffe80, #0x3456

# MOVW sfrp, #word: CB sfr datal datah
# CHECK: movw 0xfff30, #13398
# CHECK-SAME: encoding: [0xcb,0x30,0x56,0x34]
movw 0xfff30, #0x3456

# MOVW AX, saddrp: AD saddr
# CHECK: movw ax, 0xffe80
# CHECK-SAME: encoding: [0xad,0x80]
movw ax, 0xffe80

# MOVW saddrp, AX: BD saddr
# CHECK: movw 0xffe80, ax
# CHECK-SAME: encoding: [0xbd,0x80]
movw 0xffe80, ax

# MOVW AX, sfrp: AE sfr
# CHECK: movw ax, 0xfff30
# CHECK-SAME: encoding: [0xae,0x30]
movw ax, 0xfff30

# MOVW sfrp, AX: BE sfr
# CHECK: movw 0xfff30, ax
# CHECK-SAME: encoding: [0xbe,0x30]
movw 0xfff30, ax

# MOVW AX, BC: 13
# CHECK: movw ax, bc
# CHECK-SAME: encoding: [0x13]
movw ax, bc

# MOVW AX, DE: 15
# CHECK: movw ax, de
# CHECK-SAME: encoding: [0x15]
movw ax, de

# MOVW AX, HL: 17
# CHECK: movw ax, hl
# CHECK-SAME: encoding: [0x17]
movw ax, hl

# MOVW BC, AX: 12
# CHECK: movw bc, ax
# CHECK-SAME: encoding: [0x12]
movw bc, ax

# MOVW DE, AX: 14
# CHECK: movw de, ax
# CHECK-SAME: encoding: [0x14]
movw de, ax

# MOVW HL, AX: 16
# CHECK: movw hl, ax
# CHECK-SAME: encoding: [0x16]
movw hl, ax

# MOVW AX, !addr16: AF adrl adrh
# CHECK: movw ax, !0xf1234
# CHECK-SAME: encoding: [0xaf,0x34,0x12]
movw ax, !0x1234

# MOVW !addr16, AX: BF adrl adrh
# CHECK: movw !0xf1234, ax
# CHECK-SAME: encoding: [0xbf,0x34,0x12]
movw !0x1234, ax

# MOVW AX, [DE]: A9
# CHECK: movw ax, [de]
# CHECK-SAME: encoding: [0xa9]
movw ax, [de]

# MOVW [DE], AX: B9
# CHECK: movw [de], ax
# CHECK-SAME: encoding: [0xb9]
movw [de], ax

# MOVW AX, [DE+byte]: AA adr
# CHECK: movw ax, [de+5]
# CHECK-SAME: encoding: [0xaa,0x05]
movw ax, [de+0x5]

# MOVW [DE+byte], AX: BA adr
# CHECK: movw [de+5], ax
# CHECK-SAME: encoding: [0xba,0x05]
movw [de+0x5], ax

# MOVW AX, [HL]: AB
# CHECK: movw ax, [hl]
# CHECK-SAME: encoding: [0xab]
movw ax, [hl]

# MOVW [HL], AX: BB
# CHECK: movw [hl], ax
# CHECK-SAME: encoding: [0xbb]
movw [hl], ax

# MOVW AX, [HL+byte]: AC adr
# CHECK: movw ax, [hl+5]
# CHECK-SAME: encoding: [0xac,0x05]
movw ax, [hl+0x5]

# MOVW [HL+byte], AX: BC adr
# CHECK: movw [hl+5], ax
# CHECK-SAME: encoding: [0xbc,0x05]
movw [hl+0x5], ax

# MOVW AX, word[B]: 59 adrl adrh
# CHECK: movw ax, 4660[b]
# CHECK-SAME: encoding: [0x59,0x34,0x12]
movw ax, 0x1234[b]

# MOVW word[B], AX: 58 adrl adrh
# CHECK: movw 4660[b], ax
# CHECK-SAME: encoding: [0x58,0x34,0x12]
movw 0x1234[b], ax

# MOVW AX, word[C]: 69 adrl adrh
# CHECK: movw ax, 4660[c]
# CHECK-SAME: encoding: [0x69,0x34,0x12]
movw ax, 0x1234[c]

# MOVW word[C], AX: 68 adrl adrh
# CHECK: movw 4660[c], ax
# CHECK-SAME: encoding: [0x68,0x34,0x12]
movw 0x1234[c], ax

# MOVW AX, word[BC]: 79 adrl adrh
# CHECK: movw ax, 4660[bc]
# CHECK-SAME: encoding: [0x79,0x34,0x12]
movw ax, 0x1234[bc]

# MOVW word[BC], AX: 78 adrl adrh
# CHECK: movw 4660[bc], ax
# CHECK-SAME: encoding: [0x78,0x34,0x12]
movw 0x1234[bc], ax

# MOVW AX, [SP+byte]: A8 adr
# CHECK: movw ax, [sp+5]
# CHECK-SAME: encoding: [0xa8,0x05]
movw ax, [sp+0x5]

# MOVW [SP+byte], AX: B8 adr
# CHECK: movw [sp+5], ax
# CHECK-SAME: encoding: [0xb8,0x05]
movw [sp+0x5], ax

# MOVW BC, saddrp: DA saddr
# CHECK: movw bc, 0xffe80
# CHECK-SAME: encoding: [0xda,0x80]
movw bc, 0xffe80

# MOVW BC, !addr16: DB adrl adrh
# CHECK: movw bc, !0xf1234
# CHECK-SAME: encoding: [0xdb,0x34,0x12]
movw bc, !0x1234

# MOVW DE, saddrp: EA saddr
# CHECK: movw de, 0xffe80
# CHECK-SAME: encoding: [0xea,0x80]
movw de, 0xffe80

# MOVW DE, !addr16: EB adrl adrh
# CHECK: movw de, !0xf1234
# CHECK-SAME: encoding: [0xeb,0x34,0x12]
movw de, !0x1234

# MOVW HL, saddrp: FA saddr
# CHECK: movw hl, 0xffe80
# CHECK-SAME: encoding: [0xfa,0x80]
movw hl, 0xffe80

# MOVW HL, !addr16: FB adrl adrh
# CHECK: movw hl, !0xf1234
# CHECK-SAME: encoding: [0xfb,0x34,0x12]
movw hl, !0x1234

# MOVW AX, ES:!addr16: 11 AF adrl adrh
# CHECK: movw ax, es:!0x1234
# CHECK-SAME: encoding: [0x11,0xaf,0x34,0x12]
movw ax, es:!0x1234

# MOVW ES:!addr16, AX: 11 BF adrl adrh
# CHECK: movw es:!0x1234, ax
# CHECK-SAME: encoding: [0x11,0xbf,0x34,0x12]
movw es:!0x1234, ax

# MOVW AX, ES:[DE]: 11 A9
# CHECK: movw ax, es:[de]
# CHECK-SAME: encoding: [0x11,0xa9]
movw ax, es:[de]

# MOVW ES:[DE], AX: 11 B9
# CHECK: movw es:[de], ax
# CHECK-SAME: encoding: [0x11,0xb9]
movw es:[de], ax

# MOVW AX, ES:[DE+byte]: 11 AA adr
# CHECK: movw ax, es:[de+5]
# CHECK-SAME: encoding: [0x11,0xaa,0x05]
movw ax, es:[de+0x5]

# MOVW ES:[DE+byte], AX: 11 BA adr
# CHECK: movw es:[de+5], ax
# CHECK-SAME: encoding: [0x11,0xba,0x05]
movw es:[de+0x5], ax

# MOVW AX, ES:[HL]: 11 AB
# CHECK: movw ax, es:[hl]
# CHECK-SAME: encoding: [0x11,0xab]
movw ax, es:[hl]

# MOVW ES:[HL], AX: 11 BB
# CHECK: movw es:[hl], ax
# CHECK-SAME: encoding: [0x11,0xbb]
movw es:[hl], ax

# MOVW AX, ES:[HL+byte]: 11 AC adr
# CHECK: movw ax, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0xac,0x05]
movw ax, es:[hl+0x5]

# MOVW ES:[HL+byte], AX: 11 BC adr
# CHECK: movw es:[hl+5], ax
# CHECK-SAME: encoding: [0x11,0xbc,0x05]
movw es:[hl+0x5], ax

# MOVW AX, ES:word[B]: 11 59 adrl adrh
# CHECK: movw ax, es:4660[b]
# CHECK-SAME: encoding: [0x11,0x59,0x34,0x12]
movw ax, es:0x1234[b]

# MOVW ES:word[B], AX: 11 58 adrl adrh
# CHECK: movw es:4660[b], ax
# CHECK-SAME: encoding: [0x11,0x58,0x34,0x12]
movw es:0x1234[b], ax

# MOVW AX, ES:word[C]: 11 69 adrl adrh
# CHECK: movw ax, es:4660[c]
# CHECK-SAME: encoding: [0x11,0x69,0x34,0x12]
movw ax, es:0x1234[c]

# MOVW ES:word[C], AX: 11 68 adrl adrh
# CHECK: movw es:4660[c], ax
# CHECK-SAME: encoding: [0x11,0x68,0x34,0x12]
movw es:0x1234[c], ax

# MOVW AX, ES:word[BC]: 11 79 adrl adrh
# CHECK: movw ax, es:4660[bc]
# CHECK-SAME: encoding: [0x11,0x79,0x34,0x12]
movw ax, es:0x1234[bc]

# MOVW ES:word[BC], AX: 11 78 adrl adrh
# CHECK: movw es:4660[bc], ax
# CHECK-SAME: encoding: [0x11,0x78,0x34,0x12]
movw es:0x1234[bc], ax

# MOVW BC, ES:!addr16: 11 DB adrl adrh
# CHECK: movw bc, es:!0x1234
# CHECK-SAME: encoding: [0x11,0xdb,0x34,0x12]
movw bc, es:!0x1234

# MOVW DE, ES:!addr16: 11 EB adrl adrh
# CHECK: movw de, es:!0x1234
# CHECK-SAME: encoding: [0x11,0xeb,0x34,0x12]
movw de, es:!0x1234

# MOVW HL, ES:!addr16: 11 FB adrl adrh
# CHECK: movw hl, es:!0x1234
# CHECK-SAME: encoding: [0x11,0xfb,0x34,0x12]
movw hl, es:!0x1234

# XCHW AX, BC: 33
# CHECK: xchw ax, bc
# CHECK-SAME: encoding: [0x33]
xchw ax, bc

# XCHW AX, DE: 35
# CHECK: xchw ax, de
# CHECK-SAME: encoding: [0x35]
xchw ax, de

# XCHW AX, HL: 37
# CHECK: xchw ax, hl
# CHECK-SAME: encoding: [0x37]
xchw ax, hl

# ONEW AX: E6
# CHECK: onew ax
# CHECK-SAME: encoding: [0xe6]
onew ax

# ONEW BC: E7
# CHECK: onew bc
# CHECK-SAME: encoding: [0xe7]
onew bc

# CLRW AX: F6
# CHECK: clrw ax
# CHECK-SAME: encoding: [0xf6]
clrw ax

# CLRW BC: F7
# CHECK: clrw bc
# CHECK-SAME: encoding: [0xf7]
clrw bc

# ADD A, #byte: 0C data
# CHECK: add a, #18
# CHECK-SAME: encoding: [0x0c,0x12]
add a, #0x12

# ADD saddr, #byte: 0A saddr data
# CHECK: add 0xffe80, #18
# CHECK-SAME: encoding: [0x0a,0x80,0x12]
add 0xffe80, #0x12

# ADD A, X: 61 08
# CHECK: add a, x
# CHECK-SAME: encoding: [0x61,0x08]
add a, x

# ADD A, C: 61 0A
# CHECK: add a, c
# CHECK-SAME: encoding: [0x61,0x0a]
add a, c

# ADD A, B: 61 0B
# CHECK: add a, b
# CHECK-SAME: encoding: [0x61,0x0b]
add a, b

# ADD A, E: 61 0C
# CHECK: add a, e
# CHECK-SAME: encoding: [0x61,0x0c]
add a, e

# ADD A, D: 61 0D
# CHECK: add a, d
# CHECK-SAME: encoding: [0x61,0x0d]
add a, d

# ADD A, L: 61 0E
# CHECK: add a, l
# CHECK-SAME: encoding: [0x61,0x0e]
add a, l

# ADD A, H: 61 0F
# CHECK: add a, h
# CHECK-SAME: encoding: [0x61,0x0f]
add a, h

# ADD X, A: 61 00
# CHECK: add x, a
# CHECK-SAME: encoding: [0x61,0x00]
add x, a

# ADD A, A: 61 01
# CHECK: add a, a
# CHECK-SAME: encoding: [0x61,0x01]
add a, a

# ADD C, A: 61 02
# CHECK: add c, a
# CHECK-SAME: encoding: [0x61,0x02]
add c, a

# ADD B, A: 61 03
# CHECK: add b, a
# CHECK-SAME: encoding: [0x61,0x03]
add b, a

# ADD E, A: 61 04
# CHECK: add e, a
# CHECK-SAME: encoding: [0x61,0x04]
add e, a

# ADD D, A: 61 05
# CHECK: add d, a
# CHECK-SAME: encoding: [0x61,0x05]
add d, a

# ADD L, A: 61 06
# CHECK: add l, a
# CHECK-SAME: encoding: [0x61,0x06]
add l, a

# ADD H, A: 61 07
# CHECK: add h, a
# CHECK-SAME: encoding: [0x61,0x07]
add h, a

# ADD A, saddr: 0B saddr
# CHECK: add a, 0xffe80
# CHECK-SAME: encoding: [0x0b,0x80]
add a, 0xffe80

# ADD A, !addr16: 0F adrl adrh
# CHECK: add a, !0xf1234
# CHECK-SAME: encoding: [0x0f,0x34,0x12]
add a, !0x1234

# ADD A, [HL]: 0D
# CHECK: add a, [hl]
# CHECK-SAME: encoding: [0x0d]
add a, [hl]

# ADD A, [HL+byte]: 0E adr
# CHECK: add a, [hl+5]
# CHECK-SAME: encoding: [0x0e,0x05]
add a, [hl+0x5]

# ADD A, [HL+B]: 61 80
# CHECK: add a, [hl+b]
# CHECK-SAME: encoding: [0x61,0x80]
add a, [hl+b]

# ADD A, [HL+C]: 61 82
# CHECK: add a, [hl+c]
# CHECK-SAME: encoding: [0x61,0x82]
add a, [hl+c]

# ADD A, ES:!addr16: 11 0F adrl adrh
# CHECK: add a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x0f,0x34,0x12]
add a, es:!0x1234

# ADD A, ES:[HL]: 11 0D
# CHECK: add a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x0d]
add a, es:[hl]

# ADD A, ES:[HL+byte]: 11 0E adr
# CHECK: add a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x0e,0x05]
add a, es:[hl+0x5]

# ADD A, ES:[HL+B]: 11 61 80
# CHECK: add a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0x80]
add a, es:[hl+b]

# ADD A, ES:[HL+C]: 11 61 82
# CHECK: add a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0x82]
add a, es:[hl+c]

# ADDC A, #byte: 1C data
# CHECK: addc a, #18
# CHECK-SAME: encoding: [0x1c,0x12]
addc a, #0x12

# ADDC saddr, #byte: 1A saddr data
# CHECK: addc 0xffe80, #18
# CHECK-SAME: encoding: [0x1a,0x80,0x12]
addc 0xffe80, #0x12

# ADDC A, X: 61 18
# CHECK: addc a, x
# CHECK-SAME: encoding: [0x61,0x18]
addc a, x

# ADDC A, C: 61 1A
# CHECK: addc a, c
# CHECK-SAME: encoding: [0x61,0x1a]
addc a, c

# ADDC A, B: 61 1B
# CHECK: addc a, b
# CHECK-SAME: encoding: [0x61,0x1b]
addc a, b

# ADDC A, E: 61 1C
# CHECK: addc a, e
# CHECK-SAME: encoding: [0x61,0x1c]
addc a, e

# ADDC A, D: 61 1D
# CHECK: addc a, d
# CHECK-SAME: encoding: [0x61,0x1d]
addc a, d

# ADDC A, L: 61 1E
# CHECK: addc a, l
# CHECK-SAME: encoding: [0x61,0x1e]
addc a, l

# ADDC A, H: 61 1F
# CHECK: addc a, h
# CHECK-SAME: encoding: [0x61,0x1f]
addc a, h

# ADDC X, A: 61 10
# CHECK: addc x, a
# CHECK-SAME: encoding: [0x61,0x10]
addc x, a

# ADDC A, A: 61 11
# CHECK: addc a, a
# CHECK-SAME: encoding: [0x61,0x11]
addc a, a

# ADDC C, A: 61 12
# CHECK: addc c, a
# CHECK-SAME: encoding: [0x61,0x12]
addc c, a

# ADDC B, A: 61 13
# CHECK: addc b, a
# CHECK-SAME: encoding: [0x61,0x13]
addc b, a

# ADDC E, A: 61 14
# CHECK: addc e, a
# CHECK-SAME: encoding: [0x61,0x14]
addc e, a

# ADDC D, A: 61 15
# CHECK: addc d, a
# CHECK-SAME: encoding: [0x61,0x15]
addc d, a

# ADDC L, A: 61 16
# CHECK: addc l, a
# CHECK-SAME: encoding: [0x61,0x16]
addc l, a

# ADDC H, A: 61 17
# CHECK: addc h, a
# CHECK-SAME: encoding: [0x61,0x17]
addc h, a

# ADDC A, saddr: 1B saddr
# CHECK: addc a, 0xffe80
# CHECK-SAME: encoding: [0x1b,0x80]
addc a, 0xffe80

# ADDC A, !addr16: 1F adrl adrh
# CHECK: addc a, !0xf1234
# CHECK-SAME: encoding: [0x1f,0x34,0x12]
addc a, !0x1234

# ADDC A, [HL]: 1D
# CHECK: addc a, [hl]
# CHECK-SAME: encoding: [0x1d]
addc a, [hl]

# ADDC A, [HL+byte]: 1E adr
# CHECK: addc a, [hl+5]
# CHECK-SAME: encoding: [0x1e,0x05]
addc a, [hl+0x5]

# ADDC A, [HL+B]: 61 90
# CHECK: addc a, [hl+b]
# CHECK-SAME: encoding: [0x61,0x90]
addc a, [hl+b]

# ADDC A, [HL+C]: 61 92
# CHECK: addc a, [hl+c]
# CHECK-SAME: encoding: [0x61,0x92]
addc a, [hl+c]

# ADDC A, ES:!addr16: 11 1F adrl adrh
# CHECK: addc a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x1f,0x34,0x12]
addc a, es:!0x1234

# ADDC A, ES:[HL]: 11 1D
# CHECK: addc a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x1d]
addc a, es:[hl]

# ADDC A, ES:[HL+byte]: 11 1E adr
# CHECK: addc a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x1e,0x05]
addc a, es:[hl+0x5]

# ADDC A, ES:[HL+B]: 11 61 90
# CHECK: addc a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0x90]
addc a, es:[hl+b]

# ADDC A, ES:[HL+C]: 11 61 92
# CHECK: addc a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0x92]
addc a, es:[hl+c]

# SUB A, #byte: 2C data
# CHECK: sub a, #18
# CHECK-SAME: encoding: [0x2c,0x12]
sub a, #0x12

# SUB saddr, #byte: 2A saddr data
# CHECK: sub 0xffe80, #18
# CHECK-SAME: encoding: [0x2a,0x80,0x12]
sub 0xffe80, #0x12

# SUB A, X: 61 28
# CHECK: sub a, x
# CHECK-SAME: encoding: [0x61,0x28]
sub a, x

# SUB A, C: 61 2A
# CHECK: sub a, c
# CHECK-SAME: encoding: [0x61,0x2a]
sub a, c

# SUB A, B: 61 2B
# CHECK: sub a, b
# CHECK-SAME: encoding: [0x61,0x2b]
sub a, b

# SUB A, E: 61 2C
# CHECK: sub a, e
# CHECK-SAME: encoding: [0x61,0x2c]
sub a, e

# SUB A, D: 61 2D
# CHECK: sub a, d
# CHECK-SAME: encoding: [0x61,0x2d]
sub a, d

# SUB A, L: 61 2E
# CHECK: sub a, l
# CHECK-SAME: encoding: [0x61,0x2e]
sub a, l

# SUB A, H: 61 2F
# CHECK: sub a, h
# CHECK-SAME: encoding: [0x61,0x2f]
sub a, h

# SUB X, A: 61 20
# CHECK: sub x, a
# CHECK-SAME: encoding: [0x61,0x20]
sub x, a

# SUB A, A: 61 21
# CHECK: sub a, a
# CHECK-SAME: encoding: [0x61,0x21]
sub a, a

# SUB C, A: 61 22
# CHECK: sub c, a
# CHECK-SAME: encoding: [0x61,0x22]
sub c, a

# SUB B, A: 61 23
# CHECK: sub b, a
# CHECK-SAME: encoding: [0x61,0x23]
sub b, a

# SUB E, A: 61 24
# CHECK: sub e, a
# CHECK-SAME: encoding: [0x61,0x24]
sub e, a

# SUB D, A: 61 25
# CHECK: sub d, a
# CHECK-SAME: encoding: [0x61,0x25]
sub d, a

# SUB L, A: 61 26
# CHECK: sub l, a
# CHECK-SAME: encoding: [0x61,0x26]
sub l, a

# SUB H, A: 61 27
# CHECK: sub h, a
# CHECK-SAME: encoding: [0x61,0x27]
sub h, a

# SUB A, saddr: 2B saddr
# CHECK: sub a, 0xffe80
# CHECK-SAME: encoding: [0x2b,0x80]
sub a, 0xffe80

# SUB A, !addr16: 2F adrl adrh
# CHECK: sub a, !0xf1234
# CHECK-SAME: encoding: [0x2f,0x34,0x12]
sub a, !0x1234

# SUB A, [HL]: 2D
# CHECK: sub a, [hl]
# CHECK-SAME: encoding: [0x2d]
sub a, [hl]

# SUB A, [HL+byte]: 2E adr
# CHECK: sub a, [hl+5]
# CHECK-SAME: encoding: [0x2e,0x05]
sub a, [hl+0x5]

# SUB A, [HL+B]: 61 A0
# CHECK: sub a, [hl+b]
# CHECK-SAME: encoding: [0x61,0xa0]
sub a, [hl+b]

# SUB A, [HL+C]: 61 A2
# CHECK: sub a, [hl+c]
# CHECK-SAME: encoding: [0x61,0xa2]
sub a, [hl+c]

# SUB A, ES:!addr16: 11 2F adrl adrh
# CHECK: sub a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x2f,0x34,0x12]
sub a, es:!0x1234

# SUB A, ES:[HL]: 11 2D
# CHECK: sub a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x2d]
sub a, es:[hl]

# SUB A, ES:[HL+byte]: 11 2E adr
# CHECK: sub a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x2e,0x05]
sub a, es:[hl+0x5]

# SUB A, ES:[HL+B]: 11 61 A0
# CHECK: sub a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0xa0]
sub a, es:[hl+b]

# SUB A, ES:[HL+C]: 11 61 A2
# CHECK: sub a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0xa2]
sub a, es:[hl+c]

# SUBC A, #byte: 3C data
# CHECK: subc a, #18
# CHECK-SAME: encoding: [0x3c,0x12]
subc a, #0x12

# SUBC saddr, #byte: 3A saddr data
# CHECK: subc 0xffe80, #18
# CHECK-SAME: encoding: [0x3a,0x80,0x12]
subc 0xffe80, #0x12

# SUBC A, X: 61 38
# CHECK: subc a, x
# CHECK-SAME: encoding: [0x61,0x38]
subc a, x

# SUBC A, C: 61 3A
# CHECK: subc a, c
# CHECK-SAME: encoding: [0x61,0x3a]
subc a, c

# SUBC A, B: 61 3B
# CHECK: subc a, b
# CHECK-SAME: encoding: [0x61,0x3b]
subc a, b

# SUBC A, E: 61 3C
# CHECK: subc a, e
# CHECK-SAME: encoding: [0x61,0x3c]
subc a, e

# SUBC A, D: 61 3D
# CHECK: subc a, d
# CHECK-SAME: encoding: [0x61,0x3d]
subc a, d

# SUBC A, L: 61 3E
# CHECK: subc a, l
# CHECK-SAME: encoding: [0x61,0x3e]
subc a, l

# SUBC A, H: 61 3F
# CHECK: subc a, h
# CHECK-SAME: encoding: [0x61,0x3f]
subc a, h

# SUBC X, A: 61 30
# CHECK: subc x, a
# CHECK-SAME: encoding: [0x61,0x30]
subc x, a

# SUBC A, A: 61 31
# CHECK: subc a, a
# CHECK-SAME: encoding: [0x61,0x31]
subc a, a

# SUBC C, A: 61 32
# CHECK: subc c, a
# CHECK-SAME: encoding: [0x61,0x32]
subc c, a

# SUBC B, A: 61 33
# CHECK: subc b, a
# CHECK-SAME: encoding: [0x61,0x33]
subc b, a

# SUBC E, A: 61 34
# CHECK: subc e, a
# CHECK-SAME: encoding: [0x61,0x34]
subc e, a

# SUBC D, A: 61 35
# CHECK: subc d, a
# CHECK-SAME: encoding: [0x61,0x35]
subc d, a

# SUBC L, A: 61 36
# CHECK: subc l, a
# CHECK-SAME: encoding: [0x61,0x36]
subc l, a

# SUBC H, A: 61 37
# CHECK: subc h, a
# CHECK-SAME: encoding: [0x61,0x37]
subc h, a

# SUBC A, saddr: 3B saddr
# CHECK: subc a, 0xffe80
# CHECK-SAME: encoding: [0x3b,0x80]
subc a, 0xffe80

# SUBC A, !addr16: 3F adrl adrh
# CHECK: subc a, !0xf1234
# CHECK-SAME: encoding: [0x3f,0x34,0x12]
subc a, !0x1234

# SUBC A, [HL]: 3D
# CHECK: subc a, [hl]
# CHECK-SAME: encoding: [0x3d]
subc a, [hl]

# SUBC A, [HL+byte]: 3E adr
# CHECK: subc a, [hl+5]
# CHECK-SAME: encoding: [0x3e,0x05]
subc a, [hl+0x5]

# SUBC A, [HL+B]: 61 B0
# CHECK: subc a, [hl+b]
# CHECK-SAME: encoding: [0x61,0xb0]
subc a, [hl+b]

# SUBC A, [HL+C]: 61 B2
# CHECK: subc a, [hl+c]
# CHECK-SAME: encoding: [0x61,0xb2]
subc a, [hl+c]

# SUBC A, ES:!addr16: 11 3F adrl adrh
# CHECK: subc a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x3f,0x34,0x12]
subc a, es:!0x1234

# SUBC A, ES:[HL]: 11 3D
# CHECK: subc a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x3d]
subc a, es:[hl]

# SUBC A, ES:[HL+byte]: 11 3E adr
# CHECK: subc a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x3e,0x05]
subc a, es:[hl+0x5]

# SUBC A, ES:[HL+B]: 11 61 B0
# CHECK: subc a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0xb0]
subc a, es:[hl+b]

# SUBC A, ES:[HL+C]: 11 61 B2
# CHECK: subc a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0xb2]
subc a, es:[hl+c]

# AND A, #byte: 5C data
# CHECK: and a, #18
# CHECK-SAME: encoding: [0x5c,0x12]
and a, #0x12

# AND saddr, #byte: 5A saddr data
# CHECK: and 0xffe80, #18
# CHECK-SAME: encoding: [0x5a,0x80,0x12]
and 0xffe80, #0x12

# AND A, X: 61 58
# CHECK: and a, x
# CHECK-SAME: encoding: [0x61,0x58]
and a, x

# AND A, C: 61 5A
# CHECK: and a, c
# CHECK-SAME: encoding: [0x61,0x5a]
and a, c

# AND A, B: 61 5B
# CHECK: and a, b
# CHECK-SAME: encoding: [0x61,0x5b]
and a, b

# AND A, E: 61 5C
# CHECK: and a, e
# CHECK-SAME: encoding: [0x61,0x5c]
and a, e

# AND A, D: 61 5D
# CHECK: and a, d
# CHECK-SAME: encoding: [0x61,0x5d]
and a, d

# AND A, L: 61 5E
# CHECK: and a, l
# CHECK-SAME: encoding: [0x61,0x5e]
and a, l

# AND A, H: 61 5F
# CHECK: and a, h
# CHECK-SAME: encoding: [0x61,0x5f]
and a, h

# AND X, A: 61 50
# CHECK: and x, a
# CHECK-SAME: encoding: [0x61,0x50]
and x, a

# AND A, A: 61 51
# CHECK: and a, a
# CHECK-SAME: encoding: [0x61,0x51]
and a, a

# AND C, A: 61 52
# CHECK: and c, a
# CHECK-SAME: encoding: [0x61,0x52]
and c, a

# AND B, A: 61 53
# CHECK: and b, a
# CHECK-SAME: encoding: [0x61,0x53]
and b, a

# AND E, A: 61 54
# CHECK: and e, a
# CHECK-SAME: encoding: [0x61,0x54]
and e, a

# AND D, A: 61 55
# CHECK: and d, a
# CHECK-SAME: encoding: [0x61,0x55]
and d, a

# AND L, A: 61 56
# CHECK: and l, a
# CHECK-SAME: encoding: [0x61,0x56]
and l, a

# AND H, A: 61 57
# CHECK: and h, a
# CHECK-SAME: encoding: [0x61,0x57]
and h, a

# AND A, saddr: 5B saddr
# CHECK: and a, 0xffe80
# CHECK-SAME: encoding: [0x5b,0x80]
and a, 0xffe80

# AND A, !addr16: 5F adrl adrh
# CHECK: and a, !0xf1234
# CHECK-SAME: encoding: [0x5f,0x34,0x12]
and a, !0x1234

# AND A, [HL]: 5D
# CHECK: and a, [hl]
# CHECK-SAME: encoding: [0x5d]
and a, [hl]

# AND A, [HL+byte]: 5E adr
# CHECK: and a, [hl+5]
# CHECK-SAME: encoding: [0x5e,0x05]
and a, [hl+0x5]

# AND A, [HL+B]: 61 D0
# CHECK: and a, [hl+b]
# CHECK-SAME: encoding: [0x61,0xd0]
and a, [hl+b]

# AND A, [HL+C]: 61 D2
# CHECK: and a, [hl+c]
# CHECK-SAME: encoding: [0x61,0xd2]
and a, [hl+c]

# AND A, ES:!addr16: 11 5F adrl adrh
# CHECK: and a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x5f,0x34,0x12]
and a, es:!0x1234

# AND A, ES:[HL]: 11 5D
# CHECK: and a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x5d]
and a, es:[hl]

# AND A, ES:[HL+byte]: 11 5E adr
# CHECK: and a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x5e,0x05]
and a, es:[hl+0x5]

# AND A, ES:[HL+B]: 11 61 D0
# CHECK: and a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0xd0]
and a, es:[hl+b]

# AND A, ES:[HL+C]: 11 61 D2
# CHECK: and a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0xd2]
and a, es:[hl+c]

# OR A, #byte: 6C data
# CHECK: or a, #18
# CHECK-SAME: encoding: [0x6c,0x12]
or a, #0x12

# OR saddr, #byte: 6A saddr data
# CHECK: or 0xffe80, #18
# CHECK-SAME: encoding: [0x6a,0x80,0x12]
or 0xffe80, #0x12

# OR A, X: 61 68
# CHECK: or a, x
# CHECK-SAME: encoding: [0x61,0x68]
or a, x

# OR A, C: 61 6A
# CHECK: or a, c
# CHECK-SAME: encoding: [0x61,0x6a]
or a, c

# OR A, B: 61 6B
# CHECK: or a, b
# CHECK-SAME: encoding: [0x61,0x6b]
or a, b

# OR A, E: 61 6C
# CHECK: or a, e
# CHECK-SAME: encoding: [0x61,0x6c]
or a, e

# OR A, D: 61 6D
# CHECK: or a, d
# CHECK-SAME: encoding: [0x61,0x6d]
or a, d

# OR A, L: 61 6E
# CHECK: or a, l
# CHECK-SAME: encoding: [0x61,0x6e]
or a, l

# OR A, H: 61 6F
# CHECK: or a, h
# CHECK-SAME: encoding: [0x61,0x6f]
or a, h

# OR X, A: 61 60
# CHECK: or x, a
# CHECK-SAME: encoding: [0x61,0x60]
or x, a

# OR A, A: 61 61
# CHECK: or a, a
# CHECK-SAME: encoding: [0x61,0x61]
or a, a

# OR C, A: 61 62
# CHECK: or c, a
# CHECK-SAME: encoding: [0x61,0x62]
or c, a

# OR B, A: 61 63
# CHECK: or b, a
# CHECK-SAME: encoding: [0x61,0x63]
or b, a

# OR E, A: 61 64
# CHECK: or e, a
# CHECK-SAME: encoding: [0x61,0x64]
or e, a

# OR D, A: 61 65
# CHECK: or d, a
# CHECK-SAME: encoding: [0x61,0x65]
or d, a

# OR L, A: 61 66
# CHECK: or l, a
# CHECK-SAME: encoding: [0x61,0x66]
or l, a

# OR H, A: 61 67
# CHECK: or h, a
# CHECK-SAME: encoding: [0x61,0x67]
or h, a

# OR A, saddr: 6B saddr
# CHECK: or a, 0xffe80
# CHECK-SAME: encoding: [0x6b,0x80]
or a, 0xffe80

# OR A, !addr16: 6F adrl adrh
# CHECK: or a, !0xf1234
# CHECK-SAME: encoding: [0x6f,0x34,0x12]
or a, !0x1234

# OR A, [HL]: 6D
# CHECK: or a, [hl]
# CHECK-SAME: encoding: [0x6d]
or a, [hl]

# OR A, [HL+byte]: 6E adr
# CHECK: or a, [hl+5]
# CHECK-SAME: encoding: [0x6e,0x05]
or a, [hl+0x5]

# OR A, [HL+B]: 61 E0
# CHECK: or a, [hl+b]
# CHECK-SAME: encoding: [0x61,0xe0]
or a, [hl+b]

# OR A, [HL+C]: 61 E2
# CHECK: or a, [hl+c]
# CHECK-SAME: encoding: [0x61,0xe2]
or a, [hl+c]

# OR A, ES:!addr16: 11 6F adrl adrh
# CHECK: or a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x6f,0x34,0x12]
or a, es:!0x1234

# OR A, ES:[HL]: 11 6D
# CHECK: or a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x6d]
or a, es:[hl]

# OR A, ES:[HL+byte]: 11 6E adr
# CHECK: or a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x6e,0x05]
or a, es:[hl+0x5]

# OR A, ES:[HL+B]: 11 61 E0
# CHECK: or a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0xe0]
or a, es:[hl+b]

# OR A, ES:[HL+C]: 11 61 E2
# CHECK: or a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0xe2]
or a, es:[hl+c]

# XOR A, #byte: 7C data
# CHECK: xor a, #18
# CHECK-SAME: encoding: [0x7c,0x12]
xor a, #0x12

# XOR saddr, #byte: 7A saddr data
# CHECK: xor 0xffe80, #18
# CHECK-SAME: encoding: [0x7a,0x80,0x12]
xor 0xffe80, #0x12

# XOR A, X: 61 78
# CHECK: xor a, x
# CHECK-SAME: encoding: [0x61,0x78]
xor a, x

# XOR A, C: 61 7A
# CHECK: xor a, c
# CHECK-SAME: encoding: [0x61,0x7a]
xor a, c

# XOR A, B: 61 7B
# CHECK: xor a, b
# CHECK-SAME: encoding: [0x61,0x7b]
xor a, b

# XOR A, E: 61 7C
# CHECK: xor a, e
# CHECK-SAME: encoding: [0x61,0x7c]
xor a, e

# XOR A, D: 61 7D
# CHECK: xor a, d
# CHECK-SAME: encoding: [0x61,0x7d]
xor a, d

# XOR A, L: 61 7E
# CHECK: xor a, l
# CHECK-SAME: encoding: [0x61,0x7e]
xor a, l

# XOR A, H: 61 7F
# CHECK: xor a, h
# CHECK-SAME: encoding: [0x61,0x7f]
xor a, h

# XOR X, A: 61 70
# CHECK: xor x, a
# CHECK-SAME: encoding: [0x61,0x70]
xor x, a

# XOR A, A: 61 71
# CHECK: xor a, a
# CHECK-SAME: encoding: [0x61,0x71]
xor a, a

# XOR C, A: 61 72
# CHECK: xor c, a
# CHECK-SAME: encoding: [0x61,0x72]
xor c, a

# XOR B, A: 61 73
# CHECK: xor b, a
# CHECK-SAME: encoding: [0x61,0x73]
xor b, a

# XOR E, A: 61 74
# CHECK: xor e, a
# CHECK-SAME: encoding: [0x61,0x74]
xor e, a

# XOR D, A: 61 75
# CHECK: xor d, a
# CHECK-SAME: encoding: [0x61,0x75]
xor d, a

# XOR L, A: 61 76
# CHECK: xor l, a
# CHECK-SAME: encoding: [0x61,0x76]
xor l, a

# XOR H, A: 61 77
# CHECK: xor h, a
# CHECK-SAME: encoding: [0x61,0x77]
xor h, a

# XOR A, saddr: 7B saddr
# CHECK: xor a, 0xffe80
# CHECK-SAME: encoding: [0x7b,0x80]
xor a, 0xffe80

# XOR A, !addr16: 7F adrl adrh
# CHECK: xor a, !0xf1234
# CHECK-SAME: encoding: [0x7f,0x34,0x12]
xor a, !0x1234

# XOR A, [HL]: 7D
# CHECK: xor a, [hl]
# CHECK-SAME: encoding: [0x7d]
xor a, [hl]

# XOR A, [HL+byte]: 7E adr
# CHECK: xor a, [hl+5]
# CHECK-SAME: encoding: [0x7e,0x05]
xor a, [hl+0x5]

# XOR A, [HL+B]: 61 F0
# CHECK: xor a, [hl+b]
# CHECK-SAME: encoding: [0x61,0xf0]
xor a, [hl+b]

# XOR A, [HL+C]: 61 F2
# CHECK: xor a, [hl+c]
# CHECK-SAME: encoding: [0x61,0xf2]
xor a, [hl+c]

# XOR A, ES:!addr16: 11 7F adrl adrh
# CHECK: xor a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x7f,0x34,0x12]
xor a, es:!0x1234

# XOR A, ES:[HL]: 11 7D
# CHECK: xor a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x7d]
xor a, es:[hl]

# XOR A, ES:[HL+byte]: 11 7E adr
# CHECK: xor a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x7e,0x05]
xor a, es:[hl+0x5]

# XOR A, ES:[HL+B]: 11 61 F0
# CHECK: xor a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0xf0]
xor a, es:[hl+b]

# XOR A, ES:[HL+C]: 11 61 F2
# CHECK: xor a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0xf2]
xor a, es:[hl+c]

# CMP A, #byte: 4C data
# CHECK: cmp a, #18
# CHECK-SAME: encoding: [0x4c,0x12]
cmp a, #0x12

# CMP saddr, #byte: 4A saddr data
# CHECK: cmp 0xffe80, #18
# CHECK-SAME: encoding: [0x4a,0x80,0x12]
cmp 0xffe80, #0x12

# CMP A, X: 61 48
# CHECK: cmp a, x
# CHECK-SAME: encoding: [0x61,0x48]
cmp a, x

# CMP A, C: 61 4A
# CHECK: cmp a, c
# CHECK-SAME: encoding: [0x61,0x4a]
cmp a, c

# CMP A, B: 61 4B
# CHECK: cmp a, b
# CHECK-SAME: encoding: [0x61,0x4b]
cmp a, b

# CMP A, E: 61 4C
# CHECK: cmp a, e
# CHECK-SAME: encoding: [0x61,0x4c]
cmp a, e

# CMP A, D: 61 4D
# CHECK: cmp a, d
# CHECK-SAME: encoding: [0x61,0x4d]
cmp a, d

# CMP A, L: 61 4E
# CHECK: cmp a, l
# CHECK-SAME: encoding: [0x61,0x4e]
cmp a, l

# CMP A, H: 61 4F
# CHECK: cmp a, h
# CHECK-SAME: encoding: [0x61,0x4f]
cmp a, h

# CMP X, A: 61 40
# CHECK: cmp x, a
# CHECK-SAME: encoding: [0x61,0x40]
cmp x, a

# CMP A, A: 61 41
# CHECK: cmp a, a
# CHECK-SAME: encoding: [0x61,0x41]
cmp a, a

# CMP C, A: 61 42
# CHECK: cmp c, a
# CHECK-SAME: encoding: [0x61,0x42]
cmp c, a

# CMP B, A: 61 43
# CHECK: cmp b, a
# CHECK-SAME: encoding: [0x61,0x43]
cmp b, a

# CMP E, A: 61 44
# CHECK: cmp e, a
# CHECK-SAME: encoding: [0x61,0x44]
cmp e, a

# CMP D, A: 61 45
# CHECK: cmp d, a
# CHECK-SAME: encoding: [0x61,0x45]
cmp d, a

# CMP L, A: 61 46
# CHECK: cmp l, a
# CHECK-SAME: encoding: [0x61,0x46]
cmp l, a

# CMP H, A: 61 47
# CHECK: cmp h, a
# CHECK-SAME: encoding: [0x61,0x47]
cmp h, a

# CMP A, saddr: 4B saddr
# CHECK: cmp a, 0xffe80
# CHECK-SAME: encoding: [0x4b,0x80]
cmp a, 0xffe80

# CMP A, !addr16: 4F adrl adrh
# CHECK: cmp a, !0xf1234
# CHECK-SAME: encoding: [0x4f,0x34,0x12]
cmp a, !0x1234

# CMP A, [HL]: 4D
# CHECK: cmp a, [hl]
# CHECK-SAME: encoding: [0x4d]
cmp a, [hl]

# CMP A, [HL+byte]: 4E adr
# CHECK: cmp a, [hl+5]
# CHECK-SAME: encoding: [0x4e,0x05]
cmp a, [hl+0x5]

# CMP A, [HL+B]: 61 C0
# CHECK: cmp a, [hl+b]
# CHECK-SAME: encoding: [0x61,0xc0]
cmp a, [hl+b]

# CMP A, [HL+C]: 61 C2
# CHECK: cmp a, [hl+c]
# CHECK-SAME: encoding: [0x61,0xc2]
cmp a, [hl+c]

# CMP !addr16, #byte: 40 adrl adrh data
# CHECK: cmp !0xf1234, #18
# CHECK-SAME: encoding: [0x40,0x34,0x12,0x12]
cmp !0x1234, #0x12

# CMP A, ES:!addr16: 11 4F adrl adrh
# CHECK: cmp a, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x4f,0x34,0x12]
cmp a, es:!0x1234

# CMP A, ES:[HL]: 11 4D
# CHECK: cmp a, es:[hl]
# CHECK-SAME: encoding: [0x11,0x4d]
cmp a, es:[hl]

# CMP A, ES:[HL+byte]: 11 4E adr
# CHECK: cmp a, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x4e,0x05]
cmp a, es:[hl+0x5]

# CMP A, ES:[HL+B]: 11 61 C0
# CHECK: cmp a, es:[hl+b]
# CHECK-SAME: encoding: [0x11,0x61,0xc0]
cmp a, es:[hl+b]

# CMP A, ES:[HL+C]: 11 61 C2
# CHECK: cmp a, es:[hl+c]
# CHECK-SAME: encoding: [0x11,0x61,0xc2]
cmp a, es:[hl+c]

# CMP ES:!addr16, #byte: 11 40 adrl adrh data
# CHECK: cmp es:!0x1234, #18
# CHECK-SAME: encoding: [0x11,0x40,0x34,0x12,0x12]
cmp es:!0x1234, #0x12

# CMP0 A: D1
# CHECK: cmp0 a
# CHECK-SAME: encoding: [0xd1]
cmp0 a

# CMP0 X: D0
# CHECK: cmp0 x
# CHECK-SAME: encoding: [0xd0]
cmp0 x

# CMP0 B: D3
# CHECK: cmp0 b
# CHECK-SAME: encoding: [0xd3]
cmp0 b

# CMP0 C: D2
# CHECK: cmp0 c
# CHECK-SAME: encoding: [0xd2]
cmp0 c

# CMP0 saddr: D4 saddr
# CHECK: cmp0 0xffe80
# CHECK-SAME: encoding: [0xd4,0x80]
cmp0 0xffe80

# CMP0 !addr16: D5 adrl adrh
# CHECK: cmp0 !0xf1234
# CHECK-SAME: encoding: [0xd5,0x34,0x12]
cmp0 !0x1234

# CMP0 ES:!addr16: 11 D5 adrl adrh
# CHECK: cmp0 es:!0x1234
# CHECK-SAME: encoding: [0x11,0xd5,0x34,0x12]
cmp0 es:!0x1234

# CMPS X, [HL+byte]: 61 DE adr
# CHECK: cmps x, [hl+5]
# CHECK-SAME: encoding: [0x61,0xde,0x05]
cmps x, [hl+0x5]

# CMPS X, ES:[HL+byte]: 11 61 DE adr
# CHECK: cmps x, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x61,0xde,0x05]
cmps x, es:[hl+0x5]

# ADDW AX, #word: 04 datal datah
# CHECK: addw ax, #13398
# CHECK-SAME: encoding: [0x04,0x56,0x34]
addw ax, #0x3456

# ADDW AX, AX: 01
# CHECK: addw ax, ax
# CHECK-SAME: encoding: [0x01]
addw ax, ax

# ADDW AX, BC: 03
# CHECK: addw ax, bc
# CHECK-SAME: encoding: [0x03]
addw ax, bc

# ADDW AX, DE: 05
# CHECK: addw ax, de
# CHECK-SAME: encoding: [0x05]
addw ax, de

# ADDW AX, HL: 07
# CHECK: addw ax, hl
# CHECK-SAME: encoding: [0x07]
addw ax, hl

# ADDW AX, saddrp: 06 saddr
# CHECK: addw ax, 0xffe80
# CHECK-SAME: encoding: [0x06,0x80]
addw ax, 0xffe80

# ADDW AX, !addr16: 02 adrl adrh
# CHECK: addw ax, !0xf1234
# CHECK-SAME: encoding: [0x02,0x34,0x12]
addw ax, !0x1234

# ADDW AX, [HL+byte]: 61 09 adr
# CHECK: addw ax, [hl+5]
# CHECK-SAME: encoding: [0x61,0x09,0x05]
addw ax, [hl+0x5]

# ADDW AX, ES:!addr16: 11 02 adrl adrh
# CHECK: addw ax, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x02,0x34,0x12]
addw ax, es:!0x1234

# ADDW AX, ES:[HL+byte]: 11 61 09 adr
# CHECK: addw ax, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x61,0x09,0x05]
addw ax, es:[hl+0x5]

# SUBW AX, #word: 24 datal datah
# CHECK: subw ax, #13398
# CHECK-SAME: encoding: [0x24,0x56,0x34]
subw ax, #0x3456

# SUBW AX, BC: 23
# CHECK: subw ax, bc
# CHECK-SAME: encoding: [0x23]
subw ax, bc

# SUBW AX, DE: 25
# CHECK: subw ax, de
# CHECK-SAME: encoding: [0x25]
subw ax, de

# SUBW AX, HL: 27
# CHECK: subw ax, hl
# CHECK-SAME: encoding: [0x27]
subw ax, hl

# SUBW AX, saddrp: 26 saddr
# CHECK: subw ax, 0xffe80
# CHECK-SAME: encoding: [0x26,0x80]
subw ax, 0xffe80

# SUBW AX, !addr16: 22 adrl adrh
# CHECK: subw ax, !0xf1234
# CHECK-SAME: encoding: [0x22,0x34,0x12]
subw ax, !0x1234

# SUBW AX, [HL+byte]: 61 29 adr
# CHECK: subw ax, [hl+5]
# CHECK-SAME: encoding: [0x61,0x29,0x05]
subw ax, [hl+0x5]

# SUBW AX, ES:!addr16: 11 22 adrl adrh
# CHECK: subw ax, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x22,0x34,0x12]
subw ax, es:!0x1234

# SUBW AX, ES:[HL+byte]: 11 61 29 adr
# CHECK: subw ax, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x61,0x29,0x05]
subw ax, es:[hl+0x5]

# CMPW AX, #word: 44 datal datah
# CHECK: cmpw ax, #13398
# CHECK-SAME: encoding: [0x44,0x56,0x34]
cmpw ax, #0x3456

# CMPW AX, BC: 43
# CHECK: cmpw ax, bc
# CHECK-SAME: encoding: [0x43]
cmpw ax, bc

# CMPW AX, DE: 45
# CHECK: cmpw ax, de
# CHECK-SAME: encoding: [0x45]
cmpw ax, de

# CMPW AX, HL: 47
# CHECK: cmpw ax, hl
# CHECK-SAME: encoding: [0x47]
cmpw ax, hl

# CMPW AX, saddrp: 46 saddr
# CHECK: cmpw ax, 0xffe80
# CHECK-SAME: encoding: [0x46,0x80]
cmpw ax, 0xffe80

# CMPW AX, !addr16: 42 adrl adrh
# CHECK: cmpw ax, !0xf1234
# CHECK-SAME: encoding: [0x42,0x34,0x12]
cmpw ax, !0x1234

# CMPW AX, [HL+byte]: 61 49 adr
# CHECK: cmpw ax, [hl+5]
# CHECK-SAME: encoding: [0x61,0x49,0x05]
cmpw ax, [hl+0x5]

# CMPW AX, ES:!addr16: 11 42 adrl adrh
# CHECK: cmpw ax, es:!0x1234
# CHECK-SAME: encoding: [0x11,0x42,0x34,0x12]
cmpw ax, es:!0x1234

# CMPW AX, ES:[HL+byte]: 11 61 49 adr
# CHECK: cmpw ax, es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x61,0x49,0x05]
cmpw ax, es:[hl+0x5]

# MULU X: D6
# CHECK: mulu x
# CHECK-SAME: encoding: [0xd6]
mulu x

# MULHU : CE FB 01
# CHECK: mulhu
# CHECK-SAME: encoding: [0xce,0xfb,0x01]
mulhu

# MULH : CE FB 02
# CHECK: mulh
# CHECK-SAME: encoding: [0xce,0xfb,0x02]
mulh

# DIVHU : CE FB 03
# CHECK: divhu
# CHECK-SAME: encoding: [0xce,0xfb,0x03]
divhu

# DIVWU : CE FB 0B
# CHECK: divwu
# CHECK-SAME: encoding: [0xce,0xfb,0x0b]
divwu

# MACHU : CE FB 05
# CHECK: machu
# CHECK-SAME: encoding: [0xce,0xfb,0x05]
machu

# MACH : CE FB 06
# CHECK: mach
# CHECK-SAME: encoding: [0xce,0xfb,0x06]
mach

# INC X: 80
# CHECK: inc x
# CHECK-SAME: encoding: [0x80]
inc x

# INC A: 81
# CHECK: inc a
# CHECK-SAME: encoding: [0x81]
inc a

# INC C: 82
# CHECK: inc c
# CHECK-SAME: encoding: [0x82]
inc c

# INC B: 83
# CHECK: inc b
# CHECK-SAME: encoding: [0x83]
inc b

# INC E: 84
# CHECK: inc e
# CHECK-SAME: encoding: [0x84]
inc e

# INC D: 85
# CHECK: inc d
# CHECK-SAME: encoding: [0x85]
inc d

# INC L: 86
# CHECK: inc l
# CHECK-SAME: encoding: [0x86]
inc l

# INC H: 87
# CHECK: inc h
# CHECK-SAME: encoding: [0x87]
inc h

# INC saddr: A4 saddr
# CHECK: inc 0xffe80
# CHECK-SAME: encoding: [0xa4,0x80]
inc 0xffe80

# INC !addr16: A0 adrl adrh
# CHECK: inc !0xf1234
# CHECK-SAME: encoding: [0xa0,0x34,0x12]
inc !0x1234

# INC [HL+byte]: 61 59 adr
# CHECK: inc [hl+5]
# CHECK-SAME: encoding: [0x61,0x59,0x05]
inc [hl+0x5]

# INC ES:!addr16: 11 A0 adrl adrh
# CHECK: inc es:!0x1234
# CHECK-SAME: encoding: [0x11,0xa0,0x34,0x12]
inc es:!0x1234

# INC ES:[HL+byte]: 11 61 59 adr
# CHECK: inc es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x61,0x59,0x05]
inc es:[hl+0x5]

# DEC X: 90
# CHECK: dec x
# CHECK-SAME: encoding: [0x90]
dec x

# DEC A: 91
# CHECK: dec a
# CHECK-SAME: encoding: [0x91]
dec a

# DEC C: 92
# CHECK: dec c
# CHECK-SAME: encoding: [0x92]
dec c

# DEC B: 93
# CHECK: dec b
# CHECK-SAME: encoding: [0x93]
dec b

# DEC E: 94
# CHECK: dec e
# CHECK-SAME: encoding: [0x94]
dec e

# DEC D: 95
# CHECK: dec d
# CHECK-SAME: encoding: [0x95]
dec d

# DEC L: 96
# CHECK: dec l
# CHECK-SAME: encoding: [0x96]
dec l

# DEC H: 97
# CHECK: dec h
# CHECK-SAME: encoding: [0x97]
dec h

# DEC saddr: B4 saddr
# CHECK: dec 0xffe80
# CHECK-SAME: encoding: [0xb4,0x80]
dec 0xffe80

# DEC !addr16: B0 adrl adrh
# CHECK: dec !0xf1234
# CHECK-SAME: encoding: [0xb0,0x34,0x12]
dec !0x1234

# DEC [HL+byte]: 61 69 adr
# CHECK: dec [hl+5]
# CHECK-SAME: encoding: [0x61,0x69,0x05]
dec [hl+0x5]

# DEC ES:!addr16: 11 B0 adrl adrh
# CHECK: dec es:!0x1234
# CHECK-SAME: encoding: [0x11,0xb0,0x34,0x12]
dec es:!0x1234

# DEC ES:[HL+byte]: 11 61 69 adr
# CHECK: dec es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x61,0x69,0x05]
dec es:[hl+0x5]

# INCW AX: A1
# CHECK: incw ax
# CHECK-SAME: encoding: [0xa1]
incw ax

# INCW BC: A3
# CHECK: incw bc
# CHECK-SAME: encoding: [0xa3]
incw bc

# INCW DE: A5
# CHECK: incw de
# CHECK-SAME: encoding: [0xa5]
incw de

# INCW HL: A7
# CHECK: incw hl
# CHECK-SAME: encoding: [0xa7]
incw hl

# INCW saddrp: A6 saddr
# CHECK: incw 0xffe80
# CHECK-SAME: encoding: [0xa6,0x80]
incw 0xffe80

# INCW !addr16: A2 adrl adrh
# CHECK: incw !0xf1234
# CHECK-SAME: encoding: [0xa2,0x34,0x12]
incw !0x1234

# INCW [HL+byte]: 61 79 adr
# CHECK: incw [hl+5]
# CHECK-SAME: encoding: [0x61,0x79,0x05]
incw [hl+0x5]

# INCW ES:!addr16: 11 A2 adrl adrh
# CHECK: incw es:!0x1234
# CHECK-SAME: encoding: [0x11,0xa2,0x34,0x12]
incw es:!0x1234

# INCW ES:[HL+byte]: 11 61 79 adr
# CHECK: incw es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x61,0x79,0x05]
incw es:[hl+0x5]

# DECW AX: B1
# CHECK: decw ax
# CHECK-SAME: encoding: [0xb1]
decw ax

# DECW BC: B3
# CHECK: decw bc
# CHECK-SAME: encoding: [0xb3]
decw bc

# DECW DE: B5
# CHECK: decw de
# CHECK-SAME: encoding: [0xb5]
decw de

# DECW HL: B7
# CHECK: decw hl
# CHECK-SAME: encoding: [0xb7]
decw hl

# DECW saddrp: B6 saddr
# CHECK: decw 0xffe80
# CHECK-SAME: encoding: [0xb6,0x80]
decw 0xffe80

# DECW !addr16: B2 adrl adrh
# CHECK: decw !0xf1234
# CHECK-SAME: encoding: [0xb2,0x34,0x12]
decw !0x1234

# DECW [HL+byte]: 61 89 adr
# CHECK: decw [hl+5]
# CHECK-SAME: encoding: [0x61,0x89,0x05]
decw [hl+0x5]

# DECW ES:!addr16: 11 B2 adrl adrh
# CHECK: decw es:!0x1234
# CHECK-SAME: encoding: [0x11,0xb2,0x34,0x12]
decw es:!0x1234

# DECW ES:[HL+byte]: 11 61 89 adr
# CHECK: decw es:[hl+5]
# CHECK-SAME: encoding: [0x11,0x61,0x89,0x05]
decw es:[hl+0x5]

# SHR A, 1: 31 1A
# CHECK: shr a, 1
# CHECK-SAME: encoding: [0x31,0x1a]
shr a, 1

# SHR A, 2: 31 2A
# CHECK: shr a, 2
# CHECK-SAME: encoding: [0x31,0x2a]
shr a, 2

# SHR A, 3: 31 3A
# CHECK: shr a, 3
# CHECK-SAME: encoding: [0x31,0x3a]
shr a, 3

# SHR A, 4: 31 4A
# CHECK: shr a, 4
# CHECK-SAME: encoding: [0x31,0x4a]
shr a, 4

# SHR A, 5: 31 5A
# CHECK: shr a, 5
# CHECK-SAME: encoding: [0x31,0x5a]
shr a, 5

# SHR A, 6: 31 6A
# CHECK: shr a, 6
# CHECK-SAME: encoding: [0x31,0x6a]
shr a, 6

# SHR A, 7: 31 7A
# CHECK: shr a, 7
# CHECK-SAME: encoding: [0x31,0x7a]
shr a, 7

# SHRW AX, 1: 31 1E
# CHECK: shrw ax, 1
# CHECK-SAME: encoding: [0x31,0x1e]
shrw ax, 1

# SHRW AX, 2: 31 2E
# CHECK: shrw ax, 2
# CHECK-SAME: encoding: [0x31,0x2e]
shrw ax, 2

# SHRW AX, 3: 31 3E
# CHECK: shrw ax, 3
# CHECK-SAME: encoding: [0x31,0x3e]
shrw ax, 3

# SHRW AX, 4: 31 4E
# CHECK: shrw ax, 4
# CHECK-SAME: encoding: [0x31,0x4e]
shrw ax, 4

# SHRW AX, 5: 31 5E
# CHECK: shrw ax, 5
# CHECK-SAME: encoding: [0x31,0x5e]
shrw ax, 5

# SHRW AX, 6: 31 6E
# CHECK: shrw ax, 6
# CHECK-SAME: encoding: [0x31,0x6e]
shrw ax, 6

# SHRW AX, 7: 31 7E
# CHECK: shrw ax, 7
# CHECK-SAME: encoding: [0x31,0x7e]
shrw ax, 7

# SHRW AX, 8: 31 8E
# CHECK: shrw ax, 8
# CHECK-SAME: encoding: [0x31,0x8e]
shrw ax, 8

# SHRW AX, 9: 31 9E
# CHECK: shrw ax, 9
# CHECK-SAME: encoding: [0x31,0x9e]
shrw ax, 9

# SHRW AX, 10: 31 AE
# CHECK: shrw ax, 10
# CHECK-SAME: encoding: [0x31,0xae]
shrw ax, 10

# SHRW AX, 11: 31 BE
# CHECK: shrw ax, 11
# CHECK-SAME: encoding: [0x31,0xbe]
shrw ax, 11

# SHRW AX, 12: 31 CE
# CHECK: shrw ax, 12
# CHECK-SAME: encoding: [0x31,0xce]
shrw ax, 12

# SHRW AX, 13: 31 DE
# CHECK: shrw ax, 13
# CHECK-SAME: encoding: [0x31,0xde]
shrw ax, 13

# SHRW AX, 14: 31 EE
# CHECK: shrw ax, 14
# CHECK-SAME: encoding: [0x31,0xee]
shrw ax, 14

# SHRW AX, 15: 31 FE
# CHECK: shrw ax, 15
# CHECK-SAME: encoding: [0x31,0xfe]
shrw ax, 15

# SHL A, 1: 31 19
# CHECK: shl a, 1
# CHECK-SAME: encoding: [0x31,0x19]
shl a, 1

# SHL A, 2: 31 29
# CHECK: shl a, 2
# CHECK-SAME: encoding: [0x31,0x29]
shl a, 2

# SHL A, 3: 31 39
# CHECK: shl a, 3
# CHECK-SAME: encoding: [0x31,0x39]
shl a, 3

# SHL A, 4: 31 49
# CHECK: shl a, 4
# CHECK-SAME: encoding: [0x31,0x49]
shl a, 4

# SHL A, 5: 31 59
# CHECK: shl a, 5
# CHECK-SAME: encoding: [0x31,0x59]
shl a, 5

# SHL A, 6: 31 69
# CHECK: shl a, 6
# CHECK-SAME: encoding: [0x31,0x69]
shl a, 6

# SHL A, 7: 31 79
# CHECK: shl a, 7
# CHECK-SAME: encoding: [0x31,0x79]
shl a, 7

# SHL B, 1: 31 18
# CHECK: shl b, 1
# CHECK-SAME: encoding: [0x31,0x18]
shl b, 1

# SHL B, 2: 31 28
# CHECK: shl b, 2
# CHECK-SAME: encoding: [0x31,0x28]
shl b, 2

# SHL B, 3: 31 38
# CHECK: shl b, 3
# CHECK-SAME: encoding: [0x31,0x38]
shl b, 3

# SHL B, 4: 31 48
# CHECK: shl b, 4
# CHECK-SAME: encoding: [0x31,0x48]
shl b, 4

# SHL B, 5: 31 58
# CHECK: shl b, 5
# CHECK-SAME: encoding: [0x31,0x58]
shl b, 5

# SHL B, 6: 31 68
# CHECK: shl b, 6
# CHECK-SAME: encoding: [0x31,0x68]
shl b, 6

# SHL B, 7: 31 78
# CHECK: shl b, 7
# CHECK-SAME: encoding: [0x31,0x78]
shl b, 7

# SHL C, 1: 31 17
# CHECK: shl c, 1
# CHECK-SAME: encoding: [0x31,0x17]
shl c, 1

# SHL C, 2: 31 27
# CHECK: shl c, 2
# CHECK-SAME: encoding: [0x31,0x27]
shl c, 2

# SHL C, 3: 31 37
# CHECK: shl c, 3
# CHECK-SAME: encoding: [0x31,0x37]
shl c, 3

# SHL C, 4: 31 47
# CHECK: shl c, 4
# CHECK-SAME: encoding: [0x31,0x47]
shl c, 4

# SHL C, 5: 31 57
# CHECK: shl c, 5
# CHECK-SAME: encoding: [0x31,0x57]
shl c, 5

# SHL C, 6: 31 67
# CHECK: shl c, 6
# CHECK-SAME: encoding: [0x31,0x67]
shl c, 6

# SHL C, 7: 31 77
# CHECK: shl c, 7
# CHECK-SAME: encoding: [0x31,0x77]
shl c, 7

# SHLW AX, 1: 31 1D
# CHECK: shlw ax, 1
# CHECK-SAME: encoding: [0x31,0x1d]
shlw ax, 1

# SHLW AX, 2: 31 2D
# CHECK: shlw ax, 2
# CHECK-SAME: encoding: [0x31,0x2d]
shlw ax, 2

# SHLW AX, 3: 31 3D
# CHECK: shlw ax, 3
# CHECK-SAME: encoding: [0x31,0x3d]
shlw ax, 3

# SHLW AX, 4: 31 4D
# CHECK: shlw ax, 4
# CHECK-SAME: encoding: [0x31,0x4d]
shlw ax, 4

# SHLW AX, 5: 31 5D
# CHECK: shlw ax, 5
# CHECK-SAME: encoding: [0x31,0x5d]
shlw ax, 5

# SHLW AX, 6: 31 6D
# CHECK: shlw ax, 6
# CHECK-SAME: encoding: [0x31,0x6d]
shlw ax, 6

# SHLW AX, 7: 31 7D
# CHECK: shlw ax, 7
# CHECK-SAME: encoding: [0x31,0x7d]
shlw ax, 7

# SHLW AX, 8: 31 8D
# CHECK: shlw ax, 8
# CHECK-SAME: encoding: [0x31,0x8d]
shlw ax, 8

# SHLW AX, 9: 31 9D
# CHECK: shlw ax, 9
# CHECK-SAME: encoding: [0x31,0x9d]
shlw ax, 9

# SHLW AX, 10: 31 AD
# CHECK: shlw ax, 10
# CHECK-SAME: encoding: [0x31,0xad]
shlw ax, 10

# SHLW AX, 11: 31 BD
# CHECK: shlw ax, 11
# CHECK-SAME: encoding: [0x31,0xbd]
shlw ax, 11

# SHLW AX, 12: 31 CD
# CHECK: shlw ax, 12
# CHECK-SAME: encoding: [0x31,0xcd]
shlw ax, 12

# SHLW AX, 13: 31 DD
# CHECK: shlw ax, 13
# CHECK-SAME: encoding: [0x31,0xdd]
shlw ax, 13

# SHLW AX, 14: 31 ED
# CHECK: shlw ax, 14
# CHECK-SAME: encoding: [0x31,0xed]
shlw ax, 14

# SHLW AX, 15: 31 FD
# CHECK: shlw ax, 15
# CHECK-SAME: encoding: [0x31,0xfd]
shlw ax, 15

# SHLW BC, 1: 31 1C
# CHECK: shlw bc, 1
# CHECK-SAME: encoding: [0x31,0x1c]
shlw bc, 1

# SHLW BC, 2: 31 2C
# CHECK: shlw bc, 2
# CHECK-SAME: encoding: [0x31,0x2c]
shlw bc, 2

# SHLW BC, 3: 31 3C
# CHECK: shlw bc, 3
# CHECK-SAME: encoding: [0x31,0x3c]
shlw bc, 3

# SHLW BC, 4: 31 4C
# CHECK: shlw bc, 4
# CHECK-SAME: encoding: [0x31,0x4c]
shlw bc, 4

# SHLW BC, 5: 31 5C
# CHECK: shlw bc, 5
# CHECK-SAME: encoding: [0x31,0x5c]
shlw bc, 5

# SHLW BC, 6: 31 6C
# CHECK: shlw bc, 6
# CHECK-SAME: encoding: [0x31,0x6c]
shlw bc, 6

# SHLW BC, 7: 31 7C
# CHECK: shlw bc, 7
# CHECK-SAME: encoding: [0x31,0x7c]
shlw bc, 7

# SHLW BC, 8: 31 8C
# CHECK: shlw bc, 8
# CHECK-SAME: encoding: [0x31,0x8c]
shlw bc, 8

# SHLW BC, 9: 31 9C
# CHECK: shlw bc, 9
# CHECK-SAME: encoding: [0x31,0x9c]
shlw bc, 9

# SHLW BC, 10: 31 AC
# CHECK: shlw bc, 10
# CHECK-SAME: encoding: [0x31,0xac]
shlw bc, 10

# SHLW BC, 11: 31 BC
# CHECK: shlw bc, 11
# CHECK-SAME: encoding: [0x31,0xbc]
shlw bc, 11

# SHLW BC, 12: 31 CC
# CHECK: shlw bc, 12
# CHECK-SAME: encoding: [0x31,0xcc]
shlw bc, 12

# SHLW BC, 13: 31 DC
# CHECK: shlw bc, 13
# CHECK-SAME: encoding: [0x31,0xdc]
shlw bc, 13

# SHLW BC, 14: 31 EC
# CHECK: shlw bc, 14
# CHECK-SAME: encoding: [0x31,0xec]
shlw bc, 14

# SHLW BC, 15: 31 FC
# CHECK: shlw bc, 15
# CHECK-SAME: encoding: [0x31,0xfc]
shlw bc, 15

# SAR A, 1: 31 1B
# CHECK: sar a, 1
# CHECK-SAME: encoding: [0x31,0x1b]
sar a, 1

# SAR A, 2: 31 2B
# CHECK: sar a, 2
# CHECK-SAME: encoding: [0x31,0x2b]
sar a, 2

# SAR A, 3: 31 3B
# CHECK: sar a, 3
# CHECK-SAME: encoding: [0x31,0x3b]
sar a, 3

# SAR A, 4: 31 4B
# CHECK: sar a, 4
# CHECK-SAME: encoding: [0x31,0x4b]
sar a, 4

# SAR A, 5: 31 5B
# CHECK: sar a, 5
# CHECK-SAME: encoding: [0x31,0x5b]
sar a, 5

# SAR A, 6: 31 6B
# CHECK: sar a, 6
# CHECK-SAME: encoding: [0x31,0x6b]
sar a, 6

# SAR A, 7: 31 7B
# CHECK: sar a, 7
# CHECK-SAME: encoding: [0x31,0x7b]
sar a, 7

# SARW AX, 1: 31 1F
# CHECK: sarw ax, 1
# CHECK-SAME: encoding: [0x31,0x1f]
sarw ax, 1

# SARW AX, 2: 31 2F
# CHECK: sarw ax, 2
# CHECK-SAME: encoding: [0x31,0x2f]
sarw ax, 2

# SARW AX, 3: 31 3F
# CHECK: sarw ax, 3
# CHECK-SAME: encoding: [0x31,0x3f]
sarw ax, 3

# SARW AX, 4: 31 4F
# CHECK: sarw ax, 4
# CHECK-SAME: encoding: [0x31,0x4f]
sarw ax, 4

# SARW AX, 5: 31 5F
# CHECK: sarw ax, 5
# CHECK-SAME: encoding: [0x31,0x5f]
sarw ax, 5

# SARW AX, 6: 31 6F
# CHECK: sarw ax, 6
# CHECK-SAME: encoding: [0x31,0x6f]
sarw ax, 6

# SARW AX, 7: 31 7F
# CHECK: sarw ax, 7
# CHECK-SAME: encoding: [0x31,0x7f]
sarw ax, 7

# SARW AX, 8: 31 8F
# CHECK: sarw ax, 8
# CHECK-SAME: encoding: [0x31,0x8f]
sarw ax, 8

# SARW AX, 9: 31 9F
# CHECK: sarw ax, 9
# CHECK-SAME: encoding: [0x31,0x9f]
sarw ax, 9

# SARW AX, 10: 31 AF
# CHECK: sarw ax, 10
# CHECK-SAME: encoding: [0x31,0xaf]
sarw ax, 10

# SARW AX, 11: 31 BF
# CHECK: sarw ax, 11
# CHECK-SAME: encoding: [0x31,0xbf]
sarw ax, 11

# SARW AX, 12: 31 CF
# CHECK: sarw ax, 12
# CHECK-SAME: encoding: [0x31,0xcf]
sarw ax, 12

# SARW AX, 13: 31 DF
# CHECK: sarw ax, 13
# CHECK-SAME: encoding: [0x31,0xdf]
sarw ax, 13

# SARW AX, 14: 31 EF
# CHECK: sarw ax, 14
# CHECK-SAME: encoding: [0x31,0xef]
sarw ax, 14

# SARW AX, 15: 31 FF
# CHECK: sarw ax, 15
# CHECK-SAME: encoding: [0x31,0xff]
sarw ax, 15

# ROR A, 1: 61 DB
# CHECK: ror a, 1
# CHECK-SAME: encoding: [0x61,0xdb]
ror a, 1

# ROL A, 1: 61 EB
# CHECK: rol a, 1
# CHECK-SAME: encoding: [0x61,0xeb]
rol a, 1

# RORC A, 1: 61 FB
# CHECK: rorc a, 1
# CHECK-SAME: encoding: [0x61,0xfb]
rorc a, 1

# ROLC A, 1: 61 DC
# CHECK: rolc a, 1
# CHECK-SAME: encoding: [0x61,0xdc]
rolc a, 1

# ROLWC AX, 1: 61 EE
# CHECK: rolwc ax, 1
# CHECK-SAME: encoding: [0x61,0xee]
rolwc ax, 1

# ROLWC BC, 1: 61 FE
# CHECK: rolwc bc, 1
# CHECK-SAME: encoding: [0x61,0xfe]
rolwc bc, 1

# MOV1 CY, saddr.0: 71 04 saddr
# CHECK: mov1 cy, 0xffe80.0
# CHECK-SAME: encoding: [0x71,0x04,0x80]
mov1 cy, 0xffe80.0

# MOV1 CY, saddr.1: 71 14 saddr
# CHECK: mov1 cy, 0xffe80.1
# CHECK-SAME: encoding: [0x71,0x14,0x80]
mov1 cy, 0xffe80.1

# MOV1 CY, saddr.2: 71 24 saddr
# CHECK: mov1 cy, 0xffe80.2
# CHECK-SAME: encoding: [0x71,0x24,0x80]
mov1 cy, 0xffe80.2

# MOV1 CY, saddr.3: 71 34 saddr
# CHECK: mov1 cy, 0xffe80.3
# CHECK-SAME: encoding: [0x71,0x34,0x80]
mov1 cy, 0xffe80.3

# MOV1 CY, saddr.4: 71 44 saddr
# CHECK: mov1 cy, 0xffe80.4
# CHECK-SAME: encoding: [0x71,0x44,0x80]
mov1 cy, 0xffe80.4

# MOV1 CY, saddr.5: 71 54 saddr
# CHECK: mov1 cy, 0xffe80.5
# CHECK-SAME: encoding: [0x71,0x54,0x80]
mov1 cy, 0xffe80.5

# MOV1 CY, saddr.6: 71 64 saddr
# CHECK: mov1 cy, 0xffe80.6
# CHECK-SAME: encoding: [0x71,0x64,0x80]
mov1 cy, 0xffe80.6

# MOV1 CY, saddr.7: 71 74 saddr
# CHECK: mov1 cy, 0xffe80.7
# CHECK-SAME: encoding: [0x71,0x74,0x80]
mov1 cy, 0xffe80.7

# MOV1 CY, sfr.0: 71 0C sfr
# CHECK: mov1 cy, 0xfff30.0
# CHECK-SAME: encoding: [0x71,0x0c,0x30]
mov1 cy, 0xfff30.0

# MOV1 CY, sfr.1: 71 1C sfr
# CHECK: mov1 cy, 0xfff30.1
# CHECK-SAME: encoding: [0x71,0x1c,0x30]
mov1 cy, 0xfff30.1

# MOV1 CY, sfr.2: 71 2C sfr
# CHECK: mov1 cy, 0xfff30.2
# CHECK-SAME: encoding: [0x71,0x2c,0x30]
mov1 cy, 0xfff30.2

# MOV1 CY, sfr.3: 71 3C sfr
# CHECK: mov1 cy, 0xfff30.3
# CHECK-SAME: encoding: [0x71,0x3c,0x30]
mov1 cy, 0xfff30.3

# MOV1 CY, sfr.4: 71 4C sfr
# CHECK: mov1 cy, 0xfff30.4
# CHECK-SAME: encoding: [0x71,0x4c,0x30]
mov1 cy, 0xfff30.4

# MOV1 CY, sfr.5: 71 5C sfr
# CHECK: mov1 cy, 0xfff30.5
# CHECK-SAME: encoding: [0x71,0x5c,0x30]
mov1 cy, 0xfff30.5

# MOV1 CY, sfr.6: 71 6C sfr
# CHECK: mov1 cy, 0xfff30.6
# CHECK-SAME: encoding: [0x71,0x6c,0x30]
mov1 cy, 0xfff30.6

# MOV1 CY, sfr.7: 71 7C sfr
# CHECK: mov1 cy, 0xfff30.7
# CHECK-SAME: encoding: [0x71,0x7c,0x30]
mov1 cy, 0xfff30.7

# MOV1 CY, A.0: 71 8C
# CHECK: mov1 cy, a.0
# CHECK-SAME: encoding: [0x71,0x8c]
mov1 cy, a.0

# MOV1 CY, A.1: 71 9C
# CHECK: mov1 cy, a.1
# CHECK-SAME: encoding: [0x71,0x9c]
mov1 cy, a.1

# MOV1 CY, A.2: 71 AC
# CHECK: mov1 cy, a.2
# CHECK-SAME: encoding: [0x71,0xac]
mov1 cy, a.2

# MOV1 CY, A.3: 71 BC
# CHECK: mov1 cy, a.3
# CHECK-SAME: encoding: [0x71,0xbc]
mov1 cy, a.3

# MOV1 CY, A.4: 71 CC
# CHECK: mov1 cy, a.4
# CHECK-SAME: encoding: [0x71,0xcc]
mov1 cy, a.4

# MOV1 CY, A.5: 71 DC
# CHECK: mov1 cy, a.5
# CHECK-SAME: encoding: [0x71,0xdc]
mov1 cy, a.5

# MOV1 CY, A.6: 71 EC
# CHECK: mov1 cy, a.6
# CHECK-SAME: encoding: [0x71,0xec]
mov1 cy, a.6

# MOV1 CY, A.7: 71 FC
# CHECK: mov1 cy, a.7
# CHECK-SAME: encoding: [0x71,0xfc]
mov1 cy, a.7

# MOV1 CY, PSW.0: 71 0C FA
# CHECK: mov1 cy, psw.0
# CHECK-SAME: encoding: [0x71,0x0c,0xfa]
mov1 cy, psw.0

# MOV1 CY, PSW.1: 71 1C FA
# CHECK: mov1 cy, psw.1
# CHECK-SAME: encoding: [0x71,0x1c,0xfa]
mov1 cy, psw.1

# MOV1 CY, PSW.2: 71 2C FA
# CHECK: mov1 cy, psw.2
# CHECK-SAME: encoding: [0x71,0x2c,0xfa]
mov1 cy, psw.2

# MOV1 CY, PSW.3: 71 3C FA
# CHECK: mov1 cy, psw.3
# CHECK-SAME: encoding: [0x71,0x3c,0xfa]
mov1 cy, psw.3

# MOV1 CY, PSW.4: 71 4C FA
# CHECK: mov1 cy, psw.4
# CHECK-SAME: encoding: [0x71,0x4c,0xfa]
mov1 cy, psw.4

# MOV1 CY, PSW.5: 71 5C FA
# CHECK: mov1 cy, psw.5
# CHECK-SAME: encoding: [0x71,0x5c,0xfa]
mov1 cy, psw.5

# MOV1 CY, PSW.6: 71 6C FA
# CHECK: mov1 cy, psw.6
# CHECK-SAME: encoding: [0x71,0x6c,0xfa]
mov1 cy, psw.6

# MOV1 CY, PSW.7: 71 7C FA
# CHECK: mov1 cy, psw.7
# CHECK-SAME: encoding: [0x71,0x7c,0xfa]
mov1 cy, psw.7

# MOV1 CY, [HL].0: 71 84
# CHECK: mov1 cy, [hl].0
# CHECK-SAME: encoding: [0x71,0x84]
mov1 cy, [hl].0

# MOV1 CY, [HL].1: 71 94
# CHECK: mov1 cy, [hl].1
# CHECK-SAME: encoding: [0x71,0x94]
mov1 cy, [hl].1

# MOV1 CY, [HL].2: 71 A4
# CHECK: mov1 cy, [hl].2
# CHECK-SAME: encoding: [0x71,0xa4]
mov1 cy, [hl].2

# MOV1 CY, [HL].3: 71 B4
# CHECK: mov1 cy, [hl].3
# CHECK-SAME: encoding: [0x71,0xb4]
mov1 cy, [hl].3

# MOV1 CY, [HL].4: 71 C4
# CHECK: mov1 cy, [hl].4
# CHECK-SAME: encoding: [0x71,0xc4]
mov1 cy, [hl].4

# MOV1 CY, [HL].5: 71 D4
# CHECK: mov1 cy, [hl].5
# CHECK-SAME: encoding: [0x71,0xd4]
mov1 cy, [hl].5

# MOV1 CY, [HL].6: 71 E4
# CHECK: mov1 cy, [hl].6
# CHECK-SAME: encoding: [0x71,0xe4]
mov1 cy, [hl].6

# MOV1 CY, [HL].7: 71 F4
# CHECK: mov1 cy, [hl].7
# CHECK-SAME: encoding: [0x71,0xf4]
mov1 cy, [hl].7

# MOV1 saddr.0, CY: 71 01 saddr
# CHECK: mov1 0xffe80.0, cy
# CHECK-SAME: encoding: [0x71,0x01,0x80]
mov1 0xffe80.0, cy

# MOV1 saddr.1, CY: 71 11 saddr
# CHECK: mov1 0xffe80.1, cy
# CHECK-SAME: encoding: [0x71,0x11,0x80]
mov1 0xffe80.1, cy

# MOV1 saddr.2, CY: 71 21 saddr
# CHECK: mov1 0xffe80.2, cy
# CHECK-SAME: encoding: [0x71,0x21,0x80]
mov1 0xffe80.2, cy

# MOV1 saddr.3, CY: 71 31 saddr
# CHECK: mov1 0xffe80.3, cy
# CHECK-SAME: encoding: [0x71,0x31,0x80]
mov1 0xffe80.3, cy

# MOV1 saddr.4, CY: 71 41 saddr
# CHECK: mov1 0xffe80.4, cy
# CHECK-SAME: encoding: [0x71,0x41,0x80]
mov1 0xffe80.4, cy

# MOV1 saddr.5, CY: 71 51 saddr
# CHECK: mov1 0xffe80.5, cy
# CHECK-SAME: encoding: [0x71,0x51,0x80]
mov1 0xffe80.5, cy

# MOV1 saddr.6, CY: 71 61 saddr
# CHECK: mov1 0xffe80.6, cy
# CHECK-SAME: encoding: [0x71,0x61,0x80]
mov1 0xffe80.6, cy

# MOV1 saddr.7, CY: 71 71 saddr
# CHECK: mov1 0xffe80.7, cy
# CHECK-SAME: encoding: [0x71,0x71,0x80]
mov1 0xffe80.7, cy

# MOV1 sfr.0, CY: 71 09 sfr
# CHECK: mov1 0xfff30.0, cy
# CHECK-SAME: encoding: [0x71,0x09,0x30]
mov1 0xfff30.0, cy

# MOV1 sfr.1, CY: 71 19 sfr
# CHECK: mov1 0xfff30.1, cy
# CHECK-SAME: encoding: [0x71,0x19,0x30]
mov1 0xfff30.1, cy

# MOV1 sfr.2, CY: 71 29 sfr
# CHECK: mov1 0xfff30.2, cy
# CHECK-SAME: encoding: [0x71,0x29,0x30]
mov1 0xfff30.2, cy

# MOV1 sfr.3, CY: 71 39 sfr
# CHECK: mov1 0xfff30.3, cy
# CHECK-SAME: encoding: [0x71,0x39,0x30]
mov1 0xfff30.3, cy

# MOV1 sfr.4, CY: 71 49 sfr
# CHECK: mov1 0xfff30.4, cy
# CHECK-SAME: encoding: [0x71,0x49,0x30]
mov1 0xfff30.4, cy

# MOV1 sfr.5, CY: 71 59 sfr
# CHECK: mov1 0xfff30.5, cy
# CHECK-SAME: encoding: [0x71,0x59,0x30]
mov1 0xfff30.5, cy

# MOV1 sfr.6, CY: 71 69 sfr
# CHECK: mov1 0xfff30.6, cy
# CHECK-SAME: encoding: [0x71,0x69,0x30]
mov1 0xfff30.6, cy

# MOV1 sfr.7, CY: 71 79 sfr
# CHECK: mov1 0xfff30.7, cy
# CHECK-SAME: encoding: [0x71,0x79,0x30]
mov1 0xfff30.7, cy

# MOV1 A.0, CY: 71 89
# CHECK: mov1 a.0, cy
# CHECK-SAME: encoding: [0x71,0x89]
mov1 a.0, cy

# MOV1 A.1, CY: 71 99
# CHECK: mov1 a.1, cy
# CHECK-SAME: encoding: [0x71,0x99]
mov1 a.1, cy

# MOV1 A.2, CY: 71 A9
# CHECK: mov1 a.2, cy
# CHECK-SAME: encoding: [0x71,0xa9]
mov1 a.2, cy

# MOV1 A.3, CY: 71 B9
# CHECK: mov1 a.3, cy
# CHECK-SAME: encoding: [0x71,0xb9]
mov1 a.3, cy

# MOV1 A.4, CY: 71 C9
# CHECK: mov1 a.4, cy
# CHECK-SAME: encoding: [0x71,0xc9]
mov1 a.4, cy

# MOV1 A.5, CY: 71 D9
# CHECK: mov1 a.5, cy
# CHECK-SAME: encoding: [0x71,0xd9]
mov1 a.5, cy

# MOV1 A.6, CY: 71 E9
# CHECK: mov1 a.6, cy
# CHECK-SAME: encoding: [0x71,0xe9]
mov1 a.6, cy

# MOV1 A.7, CY: 71 F9
# CHECK: mov1 a.7, cy
# CHECK-SAME: encoding: [0x71,0xf9]
mov1 a.7, cy

# MOV1 PSW.0, CY: 71 09 FA
# CHECK: mov1 psw.0, cy
# CHECK-SAME: encoding: [0x71,0x09,0xfa]
mov1 psw.0, cy

# MOV1 PSW.1, CY: 71 19 FA
# CHECK: mov1 psw.1, cy
# CHECK-SAME: encoding: [0x71,0x19,0xfa]
mov1 psw.1, cy

# MOV1 PSW.2, CY: 71 29 FA
# CHECK: mov1 psw.2, cy
# CHECK-SAME: encoding: [0x71,0x29,0xfa]
mov1 psw.2, cy

# MOV1 PSW.3, CY: 71 39 FA
# CHECK: mov1 psw.3, cy
# CHECK-SAME: encoding: [0x71,0x39,0xfa]
mov1 psw.3, cy

# MOV1 PSW.4, CY: 71 49 FA
# CHECK: mov1 psw.4, cy
# CHECK-SAME: encoding: [0x71,0x49,0xfa]
mov1 psw.4, cy

# MOV1 PSW.5, CY: 71 59 FA
# CHECK: mov1 psw.5, cy
# CHECK-SAME: encoding: [0x71,0x59,0xfa]
mov1 psw.5, cy

# MOV1 PSW.6, CY: 71 69 FA
# CHECK: mov1 psw.6, cy
# CHECK-SAME: encoding: [0x71,0x69,0xfa]
mov1 psw.6, cy

# MOV1 PSW.7, CY: 71 79 FA
# CHECK: mov1 psw.7, cy
# CHECK-SAME: encoding: [0x71,0x79,0xfa]
mov1 psw.7, cy

# MOV1 [HL].0, CY: 71 81
# CHECK: mov1 [hl].0, cy
# CHECK-SAME: encoding: [0x71,0x81]
mov1 [hl].0, cy

# MOV1 [HL].1, CY: 71 91
# CHECK: mov1 [hl].1, cy
# CHECK-SAME: encoding: [0x71,0x91]
mov1 [hl].1, cy

# MOV1 [HL].2, CY: 71 A1
# CHECK: mov1 [hl].2, cy
# CHECK-SAME: encoding: [0x71,0xa1]
mov1 [hl].2, cy

# MOV1 [HL].3, CY: 71 B1
# CHECK: mov1 [hl].3, cy
# CHECK-SAME: encoding: [0x71,0xb1]
mov1 [hl].3, cy

# MOV1 [HL].4, CY: 71 C1
# CHECK: mov1 [hl].4, cy
# CHECK-SAME: encoding: [0x71,0xc1]
mov1 [hl].4, cy

# MOV1 [HL].5, CY: 71 D1
# CHECK: mov1 [hl].5, cy
# CHECK-SAME: encoding: [0x71,0xd1]
mov1 [hl].5, cy

# MOV1 [HL].6, CY: 71 E1
# CHECK: mov1 [hl].6, cy
# CHECK-SAME: encoding: [0x71,0xe1]
mov1 [hl].6, cy

# MOV1 [HL].7, CY: 71 F1
# CHECK: mov1 [hl].7, cy
# CHECK-SAME: encoding: [0x71,0xf1]
mov1 [hl].7, cy

# MOV1 CY, ES:[HL].0: 11 71 84
# CHECK: mov1 cy, es:[hl].0
# CHECK-SAME: encoding: [0x11,0x71,0x84]
mov1 cy, es:[hl].0

# MOV1 CY, ES:[HL].1: 11 71 94
# CHECK: mov1 cy, es:[hl].1
# CHECK-SAME: encoding: [0x11,0x71,0x94]
mov1 cy, es:[hl].1

# MOV1 CY, ES:[HL].2: 11 71 A4
# CHECK: mov1 cy, es:[hl].2
# CHECK-SAME: encoding: [0x11,0x71,0xa4]
mov1 cy, es:[hl].2

# MOV1 CY, ES:[HL].3: 11 71 B4
# CHECK: mov1 cy, es:[hl].3
# CHECK-SAME: encoding: [0x11,0x71,0xb4]
mov1 cy, es:[hl].3

# MOV1 CY, ES:[HL].4: 11 71 C4
# CHECK: mov1 cy, es:[hl].4
# CHECK-SAME: encoding: [0x11,0x71,0xc4]
mov1 cy, es:[hl].4

# MOV1 CY, ES:[HL].5: 11 71 D4
# CHECK: mov1 cy, es:[hl].5
# CHECK-SAME: encoding: [0x11,0x71,0xd4]
mov1 cy, es:[hl].5

# MOV1 CY, ES:[HL].6: 11 71 E4
# CHECK: mov1 cy, es:[hl].6
# CHECK-SAME: encoding: [0x11,0x71,0xe4]
mov1 cy, es:[hl].6

# MOV1 CY, ES:[HL].7: 11 71 F4
# CHECK: mov1 cy, es:[hl].7
# CHECK-SAME: encoding: [0x11,0x71,0xf4]
mov1 cy, es:[hl].7

# MOV1 ES:[HL].0, CY: 11 71 81
# CHECK: mov1 es:[hl].0, cy
# CHECK-SAME: encoding: [0x11,0x71,0x81]
mov1 es:[hl].0, cy

# MOV1 ES:[HL].1, CY: 11 71 91
# CHECK: mov1 es:[hl].1, cy
# CHECK-SAME: encoding: [0x11,0x71,0x91]
mov1 es:[hl].1, cy

# MOV1 ES:[HL].2, CY: 11 71 A1
# CHECK: mov1 es:[hl].2, cy
# CHECK-SAME: encoding: [0x11,0x71,0xa1]
mov1 es:[hl].2, cy

# MOV1 ES:[HL].3, CY: 11 71 B1
# CHECK: mov1 es:[hl].3, cy
# CHECK-SAME: encoding: [0x11,0x71,0xb1]
mov1 es:[hl].3, cy

# MOV1 ES:[HL].4, CY: 11 71 C1
# CHECK: mov1 es:[hl].4, cy
# CHECK-SAME: encoding: [0x11,0x71,0xc1]
mov1 es:[hl].4, cy

# MOV1 ES:[HL].5, CY: 11 71 D1
# CHECK: mov1 es:[hl].5, cy
# CHECK-SAME: encoding: [0x11,0x71,0xd1]
mov1 es:[hl].5, cy

# MOV1 ES:[HL].6, CY: 11 71 E1
# CHECK: mov1 es:[hl].6, cy
# CHECK-SAME: encoding: [0x11,0x71,0xe1]
mov1 es:[hl].6, cy

# MOV1 ES:[HL].7, CY: 11 71 F1
# CHECK: mov1 es:[hl].7, cy
# CHECK-SAME: encoding: [0x11,0x71,0xf1]
mov1 es:[hl].7, cy

# AND1 CY, saddr.0: 71 05 saddr
# CHECK: and1 cy, 0xffe80.0
# CHECK-SAME: encoding: [0x71,0x05,0x80]
and1 cy, 0xffe80.0

# AND1 CY, saddr.1: 71 15 saddr
# CHECK: and1 cy, 0xffe80.1
# CHECK-SAME: encoding: [0x71,0x15,0x80]
and1 cy, 0xffe80.1

# AND1 CY, saddr.2: 71 25 saddr
# CHECK: and1 cy, 0xffe80.2
# CHECK-SAME: encoding: [0x71,0x25,0x80]
and1 cy, 0xffe80.2

# AND1 CY, saddr.3: 71 35 saddr
# CHECK: and1 cy, 0xffe80.3
# CHECK-SAME: encoding: [0x71,0x35,0x80]
and1 cy, 0xffe80.3

# AND1 CY, saddr.4: 71 45 saddr
# CHECK: and1 cy, 0xffe80.4
# CHECK-SAME: encoding: [0x71,0x45,0x80]
and1 cy, 0xffe80.4

# AND1 CY, saddr.5: 71 55 saddr
# CHECK: and1 cy, 0xffe80.5
# CHECK-SAME: encoding: [0x71,0x55,0x80]
and1 cy, 0xffe80.5

# AND1 CY, saddr.6: 71 65 saddr
# CHECK: and1 cy, 0xffe80.6
# CHECK-SAME: encoding: [0x71,0x65,0x80]
and1 cy, 0xffe80.6

# AND1 CY, saddr.7: 71 75 saddr
# CHECK: and1 cy, 0xffe80.7
# CHECK-SAME: encoding: [0x71,0x75,0x80]
and1 cy, 0xffe80.7

# AND1 CY, sfr.0: 71 0D sfr
# CHECK: and1 cy, 0xfff30.0
# CHECK-SAME: encoding: [0x71,0x0d,0x30]
and1 cy, 0xfff30.0

# AND1 CY, sfr.1: 71 1D sfr
# CHECK: and1 cy, 0xfff30.1
# CHECK-SAME: encoding: [0x71,0x1d,0x30]
and1 cy, 0xfff30.1

# AND1 CY, sfr.2: 71 2D sfr
# CHECK: and1 cy, 0xfff30.2
# CHECK-SAME: encoding: [0x71,0x2d,0x30]
and1 cy, 0xfff30.2

# AND1 CY, sfr.3: 71 3D sfr
# CHECK: and1 cy, 0xfff30.3
# CHECK-SAME: encoding: [0x71,0x3d,0x30]
and1 cy, 0xfff30.3

# AND1 CY, sfr.4: 71 4D sfr
# CHECK: and1 cy, 0xfff30.4
# CHECK-SAME: encoding: [0x71,0x4d,0x30]
and1 cy, 0xfff30.4

# AND1 CY, sfr.5: 71 5D sfr
# CHECK: and1 cy, 0xfff30.5
# CHECK-SAME: encoding: [0x71,0x5d,0x30]
and1 cy, 0xfff30.5

# AND1 CY, sfr.6: 71 6D sfr
# CHECK: and1 cy, 0xfff30.6
# CHECK-SAME: encoding: [0x71,0x6d,0x30]
and1 cy, 0xfff30.6

# AND1 CY, sfr.7: 71 7D sfr
# CHECK: and1 cy, 0xfff30.7
# CHECK-SAME: encoding: [0x71,0x7d,0x30]
and1 cy, 0xfff30.7

# AND1 CY, A.0: 71 8D
# CHECK: and1 cy, a.0
# CHECK-SAME: encoding: [0x71,0x8d]
and1 cy, a.0

# AND1 CY, A.1: 71 9D
# CHECK: and1 cy, a.1
# CHECK-SAME: encoding: [0x71,0x9d]
and1 cy, a.1

# AND1 CY, A.2: 71 AD
# CHECK: and1 cy, a.2
# CHECK-SAME: encoding: [0x71,0xad]
and1 cy, a.2

# AND1 CY, A.3: 71 BD
# CHECK: and1 cy, a.3
# CHECK-SAME: encoding: [0x71,0xbd]
and1 cy, a.3

# AND1 CY, A.4: 71 CD
# CHECK: and1 cy, a.4
# CHECK-SAME: encoding: [0x71,0xcd]
and1 cy, a.4

# AND1 CY, A.5: 71 DD
# CHECK: and1 cy, a.5
# CHECK-SAME: encoding: [0x71,0xdd]
and1 cy, a.5

# AND1 CY, A.6: 71 ED
# CHECK: and1 cy, a.6
# CHECK-SAME: encoding: [0x71,0xed]
and1 cy, a.6

# AND1 CY, A.7: 71 FD
# CHECK: and1 cy, a.7
# CHECK-SAME: encoding: [0x71,0xfd]
and1 cy, a.7

# AND1 CY, PSW.0: 71 0D FA
# CHECK: and1 cy, psw.0
# CHECK-SAME: encoding: [0x71,0x0d,0xfa]
and1 cy, psw.0

# AND1 CY, PSW.1: 71 1D FA
# CHECK: and1 cy, psw.1
# CHECK-SAME: encoding: [0x71,0x1d,0xfa]
and1 cy, psw.1

# AND1 CY, PSW.2: 71 2D FA
# CHECK: and1 cy, psw.2
# CHECK-SAME: encoding: [0x71,0x2d,0xfa]
and1 cy, psw.2

# AND1 CY, PSW.3: 71 3D FA
# CHECK: and1 cy, psw.3
# CHECK-SAME: encoding: [0x71,0x3d,0xfa]
and1 cy, psw.3

# AND1 CY, PSW.4: 71 4D FA
# CHECK: and1 cy, psw.4
# CHECK-SAME: encoding: [0x71,0x4d,0xfa]
and1 cy, psw.4

# AND1 CY, PSW.5: 71 5D FA
# CHECK: and1 cy, psw.5
# CHECK-SAME: encoding: [0x71,0x5d,0xfa]
and1 cy, psw.5

# AND1 CY, PSW.6: 71 6D FA
# CHECK: and1 cy, psw.6
# CHECK-SAME: encoding: [0x71,0x6d,0xfa]
and1 cy, psw.6

# AND1 CY, PSW.7: 71 7D FA
# CHECK: and1 cy, psw.7
# CHECK-SAME: encoding: [0x71,0x7d,0xfa]
and1 cy, psw.7

# AND1 CY, [HL].0: 71 85
# CHECK: and1 cy, [hl].0
# CHECK-SAME: encoding: [0x71,0x85]
and1 cy, [hl].0

# AND1 CY, [HL].1: 71 95
# CHECK: and1 cy, [hl].1
# CHECK-SAME: encoding: [0x71,0x95]
and1 cy, [hl].1

# AND1 CY, [HL].2: 71 A5
# CHECK: and1 cy, [hl].2
# CHECK-SAME: encoding: [0x71,0xa5]
and1 cy, [hl].2

# AND1 CY, [HL].3: 71 B5
# CHECK: and1 cy, [hl].3
# CHECK-SAME: encoding: [0x71,0xb5]
and1 cy, [hl].3

# AND1 CY, [HL].4: 71 C5
# CHECK: and1 cy, [hl].4
# CHECK-SAME: encoding: [0x71,0xc5]
and1 cy, [hl].4

# AND1 CY, [HL].5: 71 D5
# CHECK: and1 cy, [hl].5
# CHECK-SAME: encoding: [0x71,0xd5]
and1 cy, [hl].5

# AND1 CY, [HL].6: 71 E5
# CHECK: and1 cy, [hl].6
# CHECK-SAME: encoding: [0x71,0xe5]
and1 cy, [hl].6

# AND1 CY, [HL].7: 71 F5
# CHECK: and1 cy, [hl].7
# CHECK-SAME: encoding: [0x71,0xf5]
and1 cy, [hl].7

# AND1 CY, ES:[HL].0: 11 71 85
# CHECK: and1 cy, es:[hl].0
# CHECK-SAME: encoding: [0x11,0x71,0x85]
and1 cy, es:[hl].0

# AND1 CY, ES:[HL].1: 11 71 95
# CHECK: and1 cy, es:[hl].1
# CHECK-SAME: encoding: [0x11,0x71,0x95]
and1 cy, es:[hl].1

# AND1 CY, ES:[HL].2: 11 71 A5
# CHECK: and1 cy, es:[hl].2
# CHECK-SAME: encoding: [0x11,0x71,0xa5]
and1 cy, es:[hl].2

# AND1 CY, ES:[HL].3: 11 71 B5
# CHECK: and1 cy, es:[hl].3
# CHECK-SAME: encoding: [0x11,0x71,0xb5]
and1 cy, es:[hl].3

# AND1 CY, ES:[HL].4: 11 71 C5
# CHECK: and1 cy, es:[hl].4
# CHECK-SAME: encoding: [0x11,0x71,0xc5]
and1 cy, es:[hl].4

# AND1 CY, ES:[HL].5: 11 71 D5
# CHECK: and1 cy, es:[hl].5
# CHECK-SAME: encoding: [0x11,0x71,0xd5]
and1 cy, es:[hl].5

# AND1 CY, ES:[HL].6: 11 71 E5
# CHECK: and1 cy, es:[hl].6
# CHECK-SAME: encoding: [0x11,0x71,0xe5]
and1 cy, es:[hl].6

# AND1 CY, ES:[HL].7: 11 71 F5
# CHECK: and1 cy, es:[hl].7
# CHECK-SAME: encoding: [0x11,0x71,0xf5]
and1 cy, es:[hl].7

# OR1 CY, saddr.0: 71 06 saddr
# CHECK: or1 cy, 0xffe80.0
# CHECK-SAME: encoding: [0x71,0x06,0x80]
or1 cy, 0xffe80.0

# OR1 CY, saddr.1: 71 16 saddr
# CHECK: or1 cy, 0xffe80.1
# CHECK-SAME: encoding: [0x71,0x16,0x80]
or1 cy, 0xffe80.1

# OR1 CY, saddr.2: 71 26 saddr
# CHECK: or1 cy, 0xffe80.2
# CHECK-SAME: encoding: [0x71,0x26,0x80]
or1 cy, 0xffe80.2

# OR1 CY, saddr.3: 71 36 saddr
# CHECK: or1 cy, 0xffe80.3
# CHECK-SAME: encoding: [0x71,0x36,0x80]
or1 cy, 0xffe80.3

# OR1 CY, saddr.4: 71 46 saddr
# CHECK: or1 cy, 0xffe80.4
# CHECK-SAME: encoding: [0x71,0x46,0x80]
or1 cy, 0xffe80.4

# OR1 CY, saddr.5: 71 56 saddr
# CHECK: or1 cy, 0xffe80.5
# CHECK-SAME: encoding: [0x71,0x56,0x80]
or1 cy, 0xffe80.5

# OR1 CY, saddr.6: 71 66 saddr
# CHECK: or1 cy, 0xffe80.6
# CHECK-SAME: encoding: [0x71,0x66,0x80]
or1 cy, 0xffe80.6

# OR1 CY, saddr.7: 71 76 saddr
# CHECK: or1 cy, 0xffe80.7
# CHECK-SAME: encoding: [0x71,0x76,0x80]
or1 cy, 0xffe80.7

# OR1 CY, sfr.0: 71 0E sfr
# CHECK: or1 cy, 0xfff30.0
# CHECK-SAME: encoding: [0x71,0x0e,0x30]
or1 cy, 0xfff30.0

# OR1 CY, sfr.1: 71 1E sfr
# CHECK: or1 cy, 0xfff30.1
# CHECK-SAME: encoding: [0x71,0x1e,0x30]
or1 cy, 0xfff30.1

# OR1 CY, sfr.2: 71 2E sfr
# CHECK: or1 cy, 0xfff30.2
# CHECK-SAME: encoding: [0x71,0x2e,0x30]
or1 cy, 0xfff30.2

# OR1 CY, sfr.3: 71 3E sfr
# CHECK: or1 cy, 0xfff30.3
# CHECK-SAME: encoding: [0x71,0x3e,0x30]
or1 cy, 0xfff30.3

# OR1 CY, sfr.4: 71 4E sfr
# CHECK: or1 cy, 0xfff30.4
# CHECK-SAME: encoding: [0x71,0x4e,0x30]
or1 cy, 0xfff30.4

# OR1 CY, sfr.5: 71 5E sfr
# CHECK: or1 cy, 0xfff30.5
# CHECK-SAME: encoding: [0x71,0x5e,0x30]
or1 cy, 0xfff30.5

# OR1 CY, sfr.6: 71 6E sfr
# CHECK: or1 cy, 0xfff30.6
# CHECK-SAME: encoding: [0x71,0x6e,0x30]
or1 cy, 0xfff30.6

# OR1 CY, sfr.7: 71 7E sfr
# CHECK: or1 cy, 0xfff30.7
# CHECK-SAME: encoding: [0x71,0x7e,0x30]
or1 cy, 0xfff30.7

# OR1 CY, A.0: 71 8E
# CHECK: or1 cy, a.0
# CHECK-SAME: encoding: [0x71,0x8e]
or1 cy, a.0

# OR1 CY, A.1: 71 9E
# CHECK: or1 cy, a.1
# CHECK-SAME: encoding: [0x71,0x9e]
or1 cy, a.1

# OR1 CY, A.2: 71 AE
# CHECK: or1 cy, a.2
# CHECK-SAME: encoding: [0x71,0xae]
or1 cy, a.2

# OR1 CY, A.3: 71 BE
# CHECK: or1 cy, a.3
# CHECK-SAME: encoding: [0x71,0xbe]
or1 cy, a.3

# OR1 CY, A.4: 71 CE
# CHECK: or1 cy, a.4
# CHECK-SAME: encoding: [0x71,0xce]
or1 cy, a.4

# OR1 CY, A.5: 71 DE
# CHECK: or1 cy, a.5
# CHECK-SAME: encoding: [0x71,0xde]
or1 cy, a.5

# OR1 CY, A.6: 71 EE
# CHECK: or1 cy, a.6
# CHECK-SAME: encoding: [0x71,0xee]
or1 cy, a.6

# OR1 CY, A.7: 71 FE
# CHECK: or1 cy, a.7
# CHECK-SAME: encoding: [0x71,0xfe]
or1 cy, a.7

# OR1 CY, PSW.0: 71 0E FA
# CHECK: or1 cy, psw.0
# CHECK-SAME: encoding: [0x71,0x0e,0xfa]
or1 cy, psw.0

# OR1 CY, PSW.1: 71 1E FA
# CHECK: or1 cy, psw.1
# CHECK-SAME: encoding: [0x71,0x1e,0xfa]
or1 cy, psw.1

# OR1 CY, PSW.2: 71 2E FA
# CHECK: or1 cy, psw.2
# CHECK-SAME: encoding: [0x71,0x2e,0xfa]
or1 cy, psw.2

# OR1 CY, PSW.3: 71 3E FA
# CHECK: or1 cy, psw.3
# CHECK-SAME: encoding: [0x71,0x3e,0xfa]
or1 cy, psw.3

# OR1 CY, PSW.4: 71 4E FA
# CHECK: or1 cy, psw.4
# CHECK-SAME: encoding: [0x71,0x4e,0xfa]
or1 cy, psw.4

# OR1 CY, PSW.5: 71 5E FA
# CHECK: or1 cy, psw.5
# CHECK-SAME: encoding: [0x71,0x5e,0xfa]
or1 cy, psw.5

# OR1 CY, PSW.6: 71 6E FA
# CHECK: or1 cy, psw.6
# CHECK-SAME: encoding: [0x71,0x6e,0xfa]
or1 cy, psw.6

# OR1 CY, PSW.7: 71 7E FA
# CHECK: or1 cy, psw.7
# CHECK-SAME: encoding: [0x71,0x7e,0xfa]
or1 cy, psw.7

# OR1 CY, [HL].0: 71 86
# CHECK: or1 cy, [hl].0
# CHECK-SAME: encoding: [0x71,0x86]
or1 cy, [hl].0

# OR1 CY, [HL].1: 71 96
# CHECK: or1 cy, [hl].1
# CHECK-SAME: encoding: [0x71,0x96]
or1 cy, [hl].1

# OR1 CY, [HL].2: 71 A6
# CHECK: or1 cy, [hl].2
# CHECK-SAME: encoding: [0x71,0xa6]
or1 cy, [hl].2

# OR1 CY, [HL].3: 71 B6
# CHECK: or1 cy, [hl].3
# CHECK-SAME: encoding: [0x71,0xb6]
or1 cy, [hl].3

# OR1 CY, [HL].4: 71 C6
# CHECK: or1 cy, [hl].4
# CHECK-SAME: encoding: [0x71,0xc6]
or1 cy, [hl].4

# OR1 CY, [HL].5: 71 D6
# CHECK: or1 cy, [hl].5
# CHECK-SAME: encoding: [0x71,0xd6]
or1 cy, [hl].5

# OR1 CY, [HL].6: 71 E6
# CHECK: or1 cy, [hl].6
# CHECK-SAME: encoding: [0x71,0xe6]
or1 cy, [hl].6

# OR1 CY, [HL].7: 71 F6
# CHECK: or1 cy, [hl].7
# CHECK-SAME: encoding: [0x71,0xf6]
or1 cy, [hl].7

# OR1 CY, ES:[HL].0: 11 71 86
# CHECK: or1 cy, es:[hl].0
# CHECK-SAME: encoding: [0x11,0x71,0x86]
or1 cy, es:[hl].0

# OR1 CY, ES:[HL].1: 11 71 96
# CHECK: or1 cy, es:[hl].1
# CHECK-SAME: encoding: [0x11,0x71,0x96]
or1 cy, es:[hl].1

# OR1 CY, ES:[HL].2: 11 71 A6
# CHECK: or1 cy, es:[hl].2
# CHECK-SAME: encoding: [0x11,0x71,0xa6]
or1 cy, es:[hl].2

# OR1 CY, ES:[HL].3: 11 71 B6
# CHECK: or1 cy, es:[hl].3
# CHECK-SAME: encoding: [0x11,0x71,0xb6]
or1 cy, es:[hl].3

# OR1 CY, ES:[HL].4: 11 71 C6
# CHECK: or1 cy, es:[hl].4
# CHECK-SAME: encoding: [0x11,0x71,0xc6]
or1 cy, es:[hl].4

# OR1 CY, ES:[HL].5: 11 71 D6
# CHECK: or1 cy, es:[hl].5
# CHECK-SAME: encoding: [0x11,0x71,0xd6]
or1 cy, es:[hl].5

# OR1 CY, ES:[HL].6: 11 71 E6
# CHECK: or1 cy, es:[hl].6
# CHECK-SAME: encoding: [0x11,0x71,0xe6]
or1 cy, es:[hl].6

# OR1 CY, ES:[HL].7: 11 71 F6
# CHECK: or1 cy, es:[hl].7
# CHECK-SAME: encoding: [0x11,0x71,0xf6]
or1 cy, es:[hl].7

# XOR1 CY, saddr.0: 71 07 saddr
# CHECK: xor1 cy, 0xffe80.0
# CHECK-SAME: encoding: [0x71,0x07,0x80]
xor1 cy, 0xffe80.0

# XOR1 CY, saddr.1: 71 17 saddr
# CHECK: xor1 cy, 0xffe80.1
# CHECK-SAME: encoding: [0x71,0x17,0x80]
xor1 cy, 0xffe80.1

# XOR1 CY, saddr.2: 71 27 saddr
# CHECK: xor1 cy, 0xffe80.2
# CHECK-SAME: encoding: [0x71,0x27,0x80]
xor1 cy, 0xffe80.2

# XOR1 CY, saddr.3: 71 37 saddr
# CHECK: xor1 cy, 0xffe80.3
# CHECK-SAME: encoding: [0x71,0x37,0x80]
xor1 cy, 0xffe80.3

# XOR1 CY, saddr.4: 71 47 saddr
# CHECK: xor1 cy, 0xffe80.4
# CHECK-SAME: encoding: [0x71,0x47,0x80]
xor1 cy, 0xffe80.4

# XOR1 CY, saddr.5: 71 57 saddr
# CHECK: xor1 cy, 0xffe80.5
# CHECK-SAME: encoding: [0x71,0x57,0x80]
xor1 cy, 0xffe80.5

# XOR1 CY, saddr.6: 71 67 saddr
# CHECK: xor1 cy, 0xffe80.6
# CHECK-SAME: encoding: [0x71,0x67,0x80]
xor1 cy, 0xffe80.6

# XOR1 CY, saddr.7: 71 77 saddr
# CHECK: xor1 cy, 0xffe80.7
# CHECK-SAME: encoding: [0x71,0x77,0x80]
xor1 cy, 0xffe80.7

# XOR1 CY, sfr.0: 71 0F sfr
# CHECK: xor1 cy, 0xfff30.0
# CHECK-SAME: encoding: [0x71,0x0f,0x30]
xor1 cy, 0xfff30.0

# XOR1 CY, sfr.1: 71 1F sfr
# CHECK: xor1 cy, 0xfff30.1
# CHECK-SAME: encoding: [0x71,0x1f,0x30]
xor1 cy, 0xfff30.1

# XOR1 CY, sfr.2: 71 2F sfr
# CHECK: xor1 cy, 0xfff30.2
# CHECK-SAME: encoding: [0x71,0x2f,0x30]
xor1 cy, 0xfff30.2

# XOR1 CY, sfr.3: 71 3F sfr
# CHECK: xor1 cy, 0xfff30.3
# CHECK-SAME: encoding: [0x71,0x3f,0x30]
xor1 cy, 0xfff30.3

# XOR1 CY, sfr.4: 71 4F sfr
# CHECK: xor1 cy, 0xfff30.4
# CHECK-SAME: encoding: [0x71,0x4f,0x30]
xor1 cy, 0xfff30.4

# XOR1 CY, sfr.5: 71 5F sfr
# CHECK: xor1 cy, 0xfff30.5
# CHECK-SAME: encoding: [0x71,0x5f,0x30]
xor1 cy, 0xfff30.5

# XOR1 CY, sfr.6: 71 6F sfr
# CHECK: xor1 cy, 0xfff30.6
# CHECK-SAME: encoding: [0x71,0x6f,0x30]
xor1 cy, 0xfff30.6

# XOR1 CY, sfr.7: 71 7F sfr
# CHECK: xor1 cy, 0xfff30.7
# CHECK-SAME: encoding: [0x71,0x7f,0x30]
xor1 cy, 0xfff30.7

# XOR1 CY, A.0: 71 8F
# CHECK: xor1 cy, a.0
# CHECK-SAME: encoding: [0x71,0x8f]
xor1 cy, a.0

# XOR1 CY, A.1: 71 9F
# CHECK: xor1 cy, a.1
# CHECK-SAME: encoding: [0x71,0x9f]
xor1 cy, a.1

# XOR1 CY, A.2: 71 AF
# CHECK: xor1 cy, a.2
# CHECK-SAME: encoding: [0x71,0xaf]
xor1 cy, a.2

# XOR1 CY, A.3: 71 BF
# CHECK: xor1 cy, a.3
# CHECK-SAME: encoding: [0x71,0xbf]
xor1 cy, a.3

# XOR1 CY, A.4: 71 CF
# CHECK: xor1 cy, a.4
# CHECK-SAME: encoding: [0x71,0xcf]
xor1 cy, a.4

# XOR1 CY, A.5: 71 DF
# CHECK: xor1 cy, a.5
# CHECK-SAME: encoding: [0x71,0xdf]
xor1 cy, a.5

# XOR1 CY, A.6: 71 EF
# CHECK: xor1 cy, a.6
# CHECK-SAME: encoding: [0x71,0xef]
xor1 cy, a.6

# XOR1 CY, A.7: 71 FF
# CHECK: xor1 cy, a.7
# CHECK-SAME: encoding: [0x71,0xff]
xor1 cy, a.7

# XOR1 CY, PSW.0: 71 0F FA
# CHECK: xor1 cy, psw.0
# CHECK-SAME: encoding: [0x71,0x0f,0xfa]
xor1 cy, psw.0

# XOR1 CY, PSW.1: 71 1F FA
# CHECK: xor1 cy, psw.1
# CHECK-SAME: encoding: [0x71,0x1f,0xfa]
xor1 cy, psw.1

# XOR1 CY, PSW.2: 71 2F FA
# CHECK: xor1 cy, psw.2
# CHECK-SAME: encoding: [0x71,0x2f,0xfa]
xor1 cy, psw.2

# XOR1 CY, PSW.3: 71 3F FA
# CHECK: xor1 cy, psw.3
# CHECK-SAME: encoding: [0x71,0x3f,0xfa]
xor1 cy, psw.3

# XOR1 CY, PSW.4: 71 4F FA
# CHECK: xor1 cy, psw.4
# CHECK-SAME: encoding: [0x71,0x4f,0xfa]
xor1 cy, psw.4

# XOR1 CY, PSW.5: 71 5F FA
# CHECK: xor1 cy, psw.5
# CHECK-SAME: encoding: [0x71,0x5f,0xfa]
xor1 cy, psw.5

# XOR1 CY, PSW.6: 71 6F FA
# CHECK: xor1 cy, psw.6
# CHECK-SAME: encoding: [0x71,0x6f,0xfa]
xor1 cy, psw.6

# XOR1 CY, PSW.7: 71 7F FA
# CHECK: xor1 cy, psw.7
# CHECK-SAME: encoding: [0x71,0x7f,0xfa]
xor1 cy, psw.7

# XOR1 CY, [HL].0: 71 87
# CHECK: xor1 cy, [hl].0
# CHECK-SAME: encoding: [0x71,0x87]
xor1 cy, [hl].0

# XOR1 CY, [HL].1: 71 97
# CHECK: xor1 cy, [hl].1
# CHECK-SAME: encoding: [0x71,0x97]
xor1 cy, [hl].1

# XOR1 CY, [HL].2: 71 A7
# CHECK: xor1 cy, [hl].2
# CHECK-SAME: encoding: [0x71,0xa7]
xor1 cy, [hl].2

# XOR1 CY, [HL].3: 71 B7
# CHECK: xor1 cy, [hl].3
# CHECK-SAME: encoding: [0x71,0xb7]
xor1 cy, [hl].3

# XOR1 CY, [HL].4: 71 C7
# CHECK: xor1 cy, [hl].4
# CHECK-SAME: encoding: [0x71,0xc7]
xor1 cy, [hl].4

# XOR1 CY, [HL].5: 71 D7
# CHECK: xor1 cy, [hl].5
# CHECK-SAME: encoding: [0x71,0xd7]
xor1 cy, [hl].5

# XOR1 CY, [HL].6: 71 E7
# CHECK: xor1 cy, [hl].6
# CHECK-SAME: encoding: [0x71,0xe7]
xor1 cy, [hl].6

# XOR1 CY, [HL].7: 71 F7
# CHECK: xor1 cy, [hl].7
# CHECK-SAME: encoding: [0x71,0xf7]
xor1 cy, [hl].7

# XOR1 CY, ES:[HL].0: 11 71 87
# CHECK: xor1 cy, es:[hl].0
# CHECK-SAME: encoding: [0x11,0x71,0x87]
xor1 cy, es:[hl].0

# XOR1 CY, ES:[HL].1: 11 71 97
# CHECK: xor1 cy, es:[hl].1
# CHECK-SAME: encoding: [0x11,0x71,0x97]
xor1 cy, es:[hl].1

# XOR1 CY, ES:[HL].2: 11 71 A7
# CHECK: xor1 cy, es:[hl].2
# CHECK-SAME: encoding: [0x11,0x71,0xa7]
xor1 cy, es:[hl].2

# XOR1 CY, ES:[HL].3: 11 71 B7
# CHECK: xor1 cy, es:[hl].3
# CHECK-SAME: encoding: [0x11,0x71,0xb7]
xor1 cy, es:[hl].3

# XOR1 CY, ES:[HL].4: 11 71 C7
# CHECK: xor1 cy, es:[hl].4
# CHECK-SAME: encoding: [0x11,0x71,0xc7]
xor1 cy, es:[hl].4

# XOR1 CY, ES:[HL].5: 11 71 D7
# CHECK: xor1 cy, es:[hl].5
# CHECK-SAME: encoding: [0x11,0x71,0xd7]
xor1 cy, es:[hl].5

# XOR1 CY, ES:[HL].6: 11 71 E7
# CHECK: xor1 cy, es:[hl].6
# CHECK-SAME: encoding: [0x11,0x71,0xe7]
xor1 cy, es:[hl].6

# XOR1 CY, ES:[HL].7: 11 71 F7
# CHECK: xor1 cy, es:[hl].7
# CHECK-SAME: encoding: [0x11,0x71,0xf7]
xor1 cy, es:[hl].7

# SET1 saddr.0: 71 02 saddr
# CHECK: set1 0xffe80.0
# CHECK-SAME: encoding: [0x71,0x02,0x80]
set1 0xffe80.0

# SET1 saddr.1: 71 12 saddr
# CHECK: set1 0xffe80.1
# CHECK-SAME: encoding: [0x71,0x12,0x80]
set1 0xffe80.1

# SET1 saddr.2: 71 22 saddr
# CHECK: set1 0xffe80.2
# CHECK-SAME: encoding: [0x71,0x22,0x80]
set1 0xffe80.2

# SET1 saddr.3: 71 32 saddr
# CHECK: set1 0xffe80.3
# CHECK-SAME: encoding: [0x71,0x32,0x80]
set1 0xffe80.3

# SET1 saddr.4: 71 42 saddr
# CHECK: set1 0xffe80.4
# CHECK-SAME: encoding: [0x71,0x42,0x80]
set1 0xffe80.4

# SET1 saddr.5: 71 52 saddr
# CHECK: set1 0xffe80.5
# CHECK-SAME: encoding: [0x71,0x52,0x80]
set1 0xffe80.5

# SET1 saddr.6: 71 62 saddr
# CHECK: set1 0xffe80.6
# CHECK-SAME: encoding: [0x71,0x62,0x80]
set1 0xffe80.6

# SET1 saddr.7: 71 72 saddr
# CHECK: set1 0xffe80.7
# CHECK-SAME: encoding: [0x71,0x72,0x80]
set1 0xffe80.7

# SET1 sfr.0: 71 0A sfr
# CHECK: set1 0xfff30.0
# CHECK-SAME: encoding: [0x71,0x0a,0x30]
set1 0xfff30.0

# SET1 sfr.1: 71 1A sfr
# CHECK: set1 0xfff30.1
# CHECK-SAME: encoding: [0x71,0x1a,0x30]
set1 0xfff30.1

# SET1 sfr.2: 71 2A sfr
# CHECK: set1 0xfff30.2
# CHECK-SAME: encoding: [0x71,0x2a,0x30]
set1 0xfff30.2

# SET1 sfr.3: 71 3A sfr
# CHECK: set1 0xfff30.3
# CHECK-SAME: encoding: [0x71,0x3a,0x30]
set1 0xfff30.3

# SET1 sfr.4: 71 4A sfr
# CHECK: set1 0xfff30.4
# CHECK-SAME: encoding: [0x71,0x4a,0x30]
set1 0xfff30.4

# SET1 sfr.5: 71 5A sfr
# CHECK: set1 0xfff30.5
# CHECK-SAME: encoding: [0x71,0x5a,0x30]
set1 0xfff30.5

# SET1 sfr.6: 71 6A sfr
# CHECK: set1 0xfff30.6
# CHECK-SAME: encoding: [0x71,0x6a,0x30]
set1 0xfff30.6

# SET1 sfr.7: 71 7A sfr
# CHECK: set1 0xfff30.7
# CHECK-SAME: encoding: [0x71,0x7a,0x30]
set1 0xfff30.7

# SET1 A.0: 71 8A
# CHECK: set1 a.0
# CHECK-SAME: encoding: [0x71,0x8a]
set1 a.0

# SET1 A.1: 71 9A
# CHECK: set1 a.1
# CHECK-SAME: encoding: [0x71,0x9a]
set1 a.1

# SET1 A.2: 71 AA
# CHECK: set1 a.2
# CHECK-SAME: encoding: [0x71,0xaa]
set1 a.2

# SET1 A.3: 71 BA
# CHECK: set1 a.3
# CHECK-SAME: encoding: [0x71,0xba]
set1 a.3

# SET1 A.4: 71 CA
# CHECK: set1 a.4
# CHECK-SAME: encoding: [0x71,0xca]
set1 a.4

# SET1 A.5: 71 DA
# CHECK: set1 a.5
# CHECK-SAME: encoding: [0x71,0xda]
set1 a.5

# SET1 A.6: 71 EA
# CHECK: set1 a.6
# CHECK-SAME: encoding: [0x71,0xea]
set1 a.6

# SET1 A.7: 71 FA
# CHECK: set1 a.7
# CHECK-SAME: encoding: [0x71,0xfa]
set1 a.7

# SET1 !addr16.0: 71 00 adrl adrh
# CHECK: set1 !0xf1234.0
# CHECK-SAME: encoding: [0x71,0x00,0x34,0x12]
set1 !0x1234.0

# SET1 !addr16.1: 71 10 adrl adrh
# CHECK: set1 !0xf1234.1
# CHECK-SAME: encoding: [0x71,0x10,0x34,0x12]
set1 !0x1234.1

# SET1 !addr16.2: 71 20 adrl adrh
# CHECK: set1 !0xf1234.2
# CHECK-SAME: encoding: [0x71,0x20,0x34,0x12]
set1 !0x1234.2

# SET1 !addr16.3: 71 30 adrl adrh
# CHECK: set1 !0xf1234.3
# CHECK-SAME: encoding: [0x71,0x30,0x34,0x12]
set1 !0x1234.3

# SET1 !addr16.4: 71 40 adrl adrh
# CHECK: set1 !0xf1234.4
# CHECK-SAME: encoding: [0x71,0x40,0x34,0x12]
set1 !0x1234.4

# SET1 !addr16.5: 71 50 adrl adrh
# CHECK: set1 !0xf1234.5
# CHECK-SAME: encoding: [0x71,0x50,0x34,0x12]
set1 !0x1234.5

# SET1 !addr16.6: 71 60 adrl adrh
# CHECK: set1 !0xf1234.6
# CHECK-SAME: encoding: [0x71,0x60,0x34,0x12]
set1 !0x1234.6

# SET1 !addr16.7: 71 70 adrl adrh
# CHECK: set1 !0xf1234.7
# CHECK-SAME: encoding: [0x71,0x70,0x34,0x12]
set1 !0x1234.7

# SET1 PSW.0: 71 0A FA
# CHECK: set1 psw.0
# CHECK-SAME: encoding: [0x71,0x0a,0xfa]
set1 psw.0

# SET1 PSW.1: 71 1A FA
# CHECK: set1 psw.1
# CHECK-SAME: encoding: [0x71,0x1a,0xfa]
set1 psw.1

# SET1 PSW.2: 71 2A FA
# CHECK: set1 psw.2
# CHECK-SAME: encoding: [0x71,0x2a,0xfa]
set1 psw.2

# SET1 PSW.3: 71 3A FA
# CHECK: set1 psw.3
# CHECK-SAME: encoding: [0x71,0x3a,0xfa]
set1 psw.3

# SET1 PSW.4: 71 4A FA
# CHECK: set1 psw.4
# CHECK-SAME: encoding: [0x71,0x4a,0xfa]
set1 psw.4

# SET1 PSW.5: 71 5A FA
# CHECK: set1 psw.5
# CHECK-SAME: encoding: [0x71,0x5a,0xfa]
set1 psw.5

# SET1 PSW.6: 71 6A FA
# CHECK: set1 psw.6
# CHECK-SAME: encoding: [0x71,0x6a,0xfa]
set1 psw.6

# SET1 PSW.7: 71 7A FA
# CHECK: set1 psw.7
# CHECK-SAME: encoding: [0x71,0x7a,0xfa]
set1 psw.7

# SET1 [HL].0: 71 82
# CHECK: set1 [hl].0
# CHECK-SAME: encoding: [0x71,0x82]
set1 [hl].0

# SET1 [HL].1: 71 92
# CHECK: set1 [hl].1
# CHECK-SAME: encoding: [0x71,0x92]
set1 [hl].1

# SET1 [HL].2: 71 A2
# CHECK: set1 [hl].2
# CHECK-SAME: encoding: [0x71,0xa2]
set1 [hl].2

# SET1 [HL].3: 71 B2
# CHECK: set1 [hl].3
# CHECK-SAME: encoding: [0x71,0xb2]
set1 [hl].3

# SET1 [HL].4: 71 C2
# CHECK: set1 [hl].4
# CHECK-SAME: encoding: [0x71,0xc2]
set1 [hl].4

# SET1 [HL].5: 71 D2
# CHECK: set1 [hl].5
# CHECK-SAME: encoding: [0x71,0xd2]
set1 [hl].5

# SET1 [HL].6: 71 E2
# CHECK: set1 [hl].6
# CHECK-SAME: encoding: [0x71,0xe2]
set1 [hl].6

# SET1 [HL].7: 71 F2
# CHECK: set1 [hl].7
# CHECK-SAME: encoding: [0x71,0xf2]
set1 [hl].7

# SET1 ES:!addr16.0: 11 71 00 adrl adrh
# CHECK: set1 es:!0x1234.0
# CHECK-SAME: encoding: [0x11,0x71,0x00,0x34,0x12]
set1 es:!0x1234.0

# SET1 ES:!addr16.1: 11 71 10 adrl adrh
# CHECK: set1 es:!0x1234.1
# CHECK-SAME: encoding: [0x11,0x71,0x10,0x34,0x12]
set1 es:!0x1234.1

# SET1 ES:!addr16.2: 11 71 20 adrl adrh
# CHECK: set1 es:!0x1234.2
# CHECK-SAME: encoding: [0x11,0x71,0x20,0x34,0x12]
set1 es:!0x1234.2

# SET1 ES:!addr16.3: 11 71 30 adrl adrh
# CHECK: set1 es:!0x1234.3
# CHECK-SAME: encoding: [0x11,0x71,0x30,0x34,0x12]
set1 es:!0x1234.3

# SET1 ES:!addr16.4: 11 71 40 adrl adrh
# CHECK: set1 es:!0x1234.4
# CHECK-SAME: encoding: [0x11,0x71,0x40,0x34,0x12]
set1 es:!0x1234.4

# SET1 ES:!addr16.5: 11 71 50 adrl adrh
# CHECK: set1 es:!0x1234.5
# CHECK-SAME: encoding: [0x11,0x71,0x50,0x34,0x12]
set1 es:!0x1234.5

# SET1 ES:!addr16.6: 11 71 60 adrl adrh
# CHECK: set1 es:!0x1234.6
# CHECK-SAME: encoding: [0x11,0x71,0x60,0x34,0x12]
set1 es:!0x1234.6

# SET1 ES:!addr16.7: 11 71 70 adrl adrh
# CHECK: set1 es:!0x1234.7
# CHECK-SAME: encoding: [0x11,0x71,0x70,0x34,0x12]
set1 es:!0x1234.7

# SET1 ES:[HL].0: 11 71 82
# CHECK: set1 es:[hl].0
# CHECK-SAME: encoding: [0x11,0x71,0x82]
set1 es:[hl].0

# SET1 ES:[HL].1: 11 71 92
# CHECK: set1 es:[hl].1
# CHECK-SAME: encoding: [0x11,0x71,0x92]
set1 es:[hl].1

# SET1 ES:[HL].2: 11 71 A2
# CHECK: set1 es:[hl].2
# CHECK-SAME: encoding: [0x11,0x71,0xa2]
set1 es:[hl].2

# SET1 ES:[HL].3: 11 71 B2
# CHECK: set1 es:[hl].3
# CHECK-SAME: encoding: [0x11,0x71,0xb2]
set1 es:[hl].3

# SET1 ES:[HL].4: 11 71 C2
# CHECK: set1 es:[hl].4
# CHECK-SAME: encoding: [0x11,0x71,0xc2]
set1 es:[hl].4

# SET1 ES:[HL].5: 11 71 D2
# CHECK: set1 es:[hl].5
# CHECK-SAME: encoding: [0x11,0x71,0xd2]
set1 es:[hl].5

# SET1 ES:[HL].6: 11 71 E2
# CHECK: set1 es:[hl].6
# CHECK-SAME: encoding: [0x11,0x71,0xe2]
set1 es:[hl].6

# SET1 ES:[HL].7: 11 71 F2
# CHECK: set1 es:[hl].7
# CHECK-SAME: encoding: [0x11,0x71,0xf2]
set1 es:[hl].7

# CLR1 saddr.0: 71 03 saddr
# CHECK: clr1 0xffe80.0
# CHECK-SAME: encoding: [0x71,0x03,0x80]
clr1 0xffe80.0

# CLR1 saddr.1: 71 13 saddr
# CHECK: clr1 0xffe80.1
# CHECK-SAME: encoding: [0x71,0x13,0x80]
clr1 0xffe80.1

# CLR1 saddr.2: 71 23 saddr
# CHECK: clr1 0xffe80.2
# CHECK-SAME: encoding: [0x71,0x23,0x80]
clr1 0xffe80.2

# CLR1 saddr.3: 71 33 saddr
# CHECK: clr1 0xffe80.3
# CHECK-SAME: encoding: [0x71,0x33,0x80]
clr1 0xffe80.3

# CLR1 saddr.4: 71 43 saddr
# CHECK: clr1 0xffe80.4
# CHECK-SAME: encoding: [0x71,0x43,0x80]
clr1 0xffe80.4

# CLR1 saddr.5: 71 53 saddr
# CHECK: clr1 0xffe80.5
# CHECK-SAME: encoding: [0x71,0x53,0x80]
clr1 0xffe80.5

# CLR1 saddr.6: 71 63 saddr
# CHECK: clr1 0xffe80.6
# CHECK-SAME: encoding: [0x71,0x63,0x80]
clr1 0xffe80.6

# CLR1 saddr.7: 71 73 saddr
# CHECK: clr1 0xffe80.7
# CHECK-SAME: encoding: [0x71,0x73,0x80]
clr1 0xffe80.7

# CLR1 sfr.0: 71 0B sfr
# CHECK: clr1 0xfff30.0
# CHECK-SAME: encoding: [0x71,0x0b,0x30]
clr1 0xfff30.0

# CLR1 sfr.1: 71 1B sfr
# CHECK: clr1 0xfff30.1
# CHECK-SAME: encoding: [0x71,0x1b,0x30]
clr1 0xfff30.1

# CLR1 sfr.2: 71 2B sfr
# CHECK: clr1 0xfff30.2
# CHECK-SAME: encoding: [0x71,0x2b,0x30]
clr1 0xfff30.2

# CLR1 sfr.3: 71 3B sfr
# CHECK: clr1 0xfff30.3
# CHECK-SAME: encoding: [0x71,0x3b,0x30]
clr1 0xfff30.3

# CLR1 sfr.4: 71 4B sfr
# CHECK: clr1 0xfff30.4
# CHECK-SAME: encoding: [0x71,0x4b,0x30]
clr1 0xfff30.4

# CLR1 sfr.5: 71 5B sfr
# CHECK: clr1 0xfff30.5
# CHECK-SAME: encoding: [0x71,0x5b,0x30]
clr1 0xfff30.5

# CLR1 sfr.6: 71 6B sfr
# CHECK: clr1 0xfff30.6
# CHECK-SAME: encoding: [0x71,0x6b,0x30]
clr1 0xfff30.6

# CLR1 sfr.7: 71 7B sfr
# CHECK: clr1 0xfff30.7
# CHECK-SAME: encoding: [0x71,0x7b,0x30]
clr1 0xfff30.7

# CLR1 A.0: 71 8B
# CHECK: clr1 a.0
# CHECK-SAME: encoding: [0x71,0x8b]
clr1 a.0

# CLR1 A.1: 71 9B
# CHECK: clr1 a.1
# CHECK-SAME: encoding: [0x71,0x9b]
clr1 a.1

# CLR1 A.2: 71 AB
# CHECK: clr1 a.2
# CHECK-SAME: encoding: [0x71,0xab]
clr1 a.2

# CLR1 A.3: 71 BB
# CHECK: clr1 a.3
# CHECK-SAME: encoding: [0x71,0xbb]
clr1 a.3

# CLR1 A.4: 71 CB
# CHECK: clr1 a.4
# CHECK-SAME: encoding: [0x71,0xcb]
clr1 a.4

# CLR1 A.5: 71 DB
# CHECK: clr1 a.5
# CHECK-SAME: encoding: [0x71,0xdb]
clr1 a.5

# CLR1 A.6: 71 EB
# CHECK: clr1 a.6
# CHECK-SAME: encoding: [0x71,0xeb]
clr1 a.6

# CLR1 A.7: 71 FB
# CHECK: clr1 a.7
# CHECK-SAME: encoding: [0x71,0xfb]
clr1 a.7

# CLR1 !addr16.0: 71 08 adrl adrh
# CHECK: clr1 !0xf1234.0
# CHECK-SAME: encoding: [0x71,0x08,0x34,0x12]
clr1 !0x1234.0

# CLR1 !addr16.1: 71 18 adrl adrh
# CHECK: clr1 !0xf1234.1
# CHECK-SAME: encoding: [0x71,0x18,0x34,0x12]
clr1 !0x1234.1

# CLR1 !addr16.2: 71 28 adrl adrh
# CHECK: clr1 !0xf1234.2
# CHECK-SAME: encoding: [0x71,0x28,0x34,0x12]
clr1 !0x1234.2

# CLR1 !addr16.3: 71 38 adrl adrh
# CHECK: clr1 !0xf1234.3
# CHECK-SAME: encoding: [0x71,0x38,0x34,0x12]
clr1 !0x1234.3

# CLR1 !addr16.4: 71 48 adrl adrh
# CHECK: clr1 !0xf1234.4
# CHECK-SAME: encoding: [0x71,0x48,0x34,0x12]
clr1 !0x1234.4

# CLR1 !addr16.5: 71 58 adrl adrh
# CHECK: clr1 !0xf1234.5
# CHECK-SAME: encoding: [0x71,0x58,0x34,0x12]
clr1 !0x1234.5

# CLR1 !addr16.6: 71 68 adrl adrh
# CHECK: clr1 !0xf1234.6
# CHECK-SAME: encoding: [0x71,0x68,0x34,0x12]
clr1 !0x1234.6

# CLR1 !addr16.7: 71 78 adrl adrh
# CHECK: clr1 !0xf1234.7
# CHECK-SAME: encoding: [0x71,0x78,0x34,0x12]
clr1 !0x1234.7

# CLR1 PSW.0: 71 0B FA
# CHECK: clr1 psw.0
# CHECK-SAME: encoding: [0x71,0x0b,0xfa]
clr1 psw.0

# CLR1 PSW.1: 71 1B FA
# CHECK: clr1 psw.1
# CHECK-SAME: encoding: [0x71,0x1b,0xfa]
clr1 psw.1

# CLR1 PSW.2: 71 2B FA
# CHECK: clr1 psw.2
# CHECK-SAME: encoding: [0x71,0x2b,0xfa]
clr1 psw.2

# CLR1 PSW.3: 71 3B FA
# CHECK: clr1 psw.3
# CHECK-SAME: encoding: [0x71,0x3b,0xfa]
clr1 psw.3

# CLR1 PSW.4: 71 4B FA
# CHECK: clr1 psw.4
# CHECK-SAME: encoding: [0x71,0x4b,0xfa]
clr1 psw.4

# CLR1 PSW.5: 71 5B FA
# CHECK: clr1 psw.5
# CHECK-SAME: encoding: [0x71,0x5b,0xfa]
clr1 psw.5

# CLR1 PSW.6: 71 6B FA
# CHECK: clr1 psw.6
# CHECK-SAME: encoding: [0x71,0x6b,0xfa]
clr1 psw.6

# CLR1 PSW.7: 71 7B FA
# CHECK: clr1 psw.7
# CHECK-SAME: encoding: [0x71,0x7b,0xfa]
clr1 psw.7

# CLR1 [HL].0: 71 83
# CHECK: clr1 [hl].0
# CHECK-SAME: encoding: [0x71,0x83]
clr1 [hl].0

# CLR1 [HL].1: 71 93
# CHECK: clr1 [hl].1
# CHECK-SAME: encoding: [0x71,0x93]
clr1 [hl].1

# CLR1 [HL].2: 71 A3
# CHECK: clr1 [hl].2
# CHECK-SAME: encoding: [0x71,0xa3]
clr1 [hl].2

# CLR1 [HL].3: 71 B3
# CHECK: clr1 [hl].3
# CHECK-SAME: encoding: [0x71,0xb3]
clr1 [hl].3

# CLR1 [HL].4: 71 C3
# CHECK: clr1 [hl].4
# CHECK-SAME: encoding: [0x71,0xc3]
clr1 [hl].4

# CLR1 [HL].5: 71 D3
# CHECK: clr1 [hl].5
# CHECK-SAME: encoding: [0x71,0xd3]
clr1 [hl].5

# CLR1 [HL].6: 71 E3
# CHECK: clr1 [hl].6
# CHECK-SAME: encoding: [0x71,0xe3]
clr1 [hl].6

# CLR1 [HL].7: 71 F3
# CHECK: clr1 [hl].7
# CHECK-SAME: encoding: [0x71,0xf3]
clr1 [hl].7

# CLR1 ES:!addr16.0: 11 71 08 adrl adrh
# CHECK: clr1 es:!0x1234.0
# CHECK-SAME: encoding: [0x11,0x71,0x08,0x34,0x12]
clr1 es:!0x1234.0

# CLR1 ES:!addr16.1: 11 71 18 adrl adrh
# CHECK: clr1 es:!0x1234.1
# CHECK-SAME: encoding: [0x11,0x71,0x18,0x34,0x12]
clr1 es:!0x1234.1

# CLR1 ES:!addr16.2: 11 71 28 adrl adrh
# CHECK: clr1 es:!0x1234.2
# CHECK-SAME: encoding: [0x11,0x71,0x28,0x34,0x12]
clr1 es:!0x1234.2

# CLR1 ES:!addr16.3: 11 71 38 adrl adrh
# CHECK: clr1 es:!0x1234.3
# CHECK-SAME: encoding: [0x11,0x71,0x38,0x34,0x12]
clr1 es:!0x1234.3

# CLR1 ES:!addr16.4: 11 71 48 adrl adrh
# CHECK: clr1 es:!0x1234.4
# CHECK-SAME: encoding: [0x11,0x71,0x48,0x34,0x12]
clr1 es:!0x1234.4

# CLR1 ES:!addr16.5: 11 71 58 adrl adrh
# CHECK: clr1 es:!0x1234.5
# CHECK-SAME: encoding: [0x11,0x71,0x58,0x34,0x12]
clr1 es:!0x1234.5

# CLR1 ES:!addr16.6: 11 71 68 adrl adrh
# CHECK: clr1 es:!0x1234.6
# CHECK-SAME: encoding: [0x11,0x71,0x68,0x34,0x12]
clr1 es:!0x1234.6

# CLR1 ES:!addr16.7: 11 71 78 adrl adrh
# CHECK: clr1 es:!0x1234.7
# CHECK-SAME: encoding: [0x11,0x71,0x78,0x34,0x12]
clr1 es:!0x1234.7

# CLR1 ES:[HL].0: 11 71 83
# CHECK: clr1 es:[hl].0
# CHECK-SAME: encoding: [0x11,0x71,0x83]
clr1 es:[hl].0

# CLR1 ES:[HL].1: 11 71 93
# CHECK: clr1 es:[hl].1
# CHECK-SAME: encoding: [0x11,0x71,0x93]
clr1 es:[hl].1

# CLR1 ES:[HL].2: 11 71 A3
# CHECK: clr1 es:[hl].2
# CHECK-SAME: encoding: [0x11,0x71,0xa3]
clr1 es:[hl].2

# CLR1 ES:[HL].3: 11 71 B3
# CHECK: clr1 es:[hl].3
# CHECK-SAME: encoding: [0x11,0x71,0xb3]
clr1 es:[hl].3

# CLR1 ES:[HL].4: 11 71 C3
# CHECK: clr1 es:[hl].4
# CHECK-SAME: encoding: [0x11,0x71,0xc3]
clr1 es:[hl].4

# CLR1 ES:[HL].5: 11 71 D3
# CHECK: clr1 es:[hl].5
# CHECK-SAME: encoding: [0x11,0x71,0xd3]
clr1 es:[hl].5

# CLR1 ES:[HL].6: 11 71 E3
# CHECK: clr1 es:[hl].6
# CHECK-SAME: encoding: [0x11,0x71,0xe3]
clr1 es:[hl].6

# CLR1 ES:[HL].7: 11 71 F3
# CHECK: clr1 es:[hl].7
# CHECK-SAME: encoding: [0x11,0x71,0xf3]
clr1 es:[hl].7

# SET1 CY: 71 80
# CHECK: set1 cy
# CHECK-SAME: encoding: [0x71,0x80]
set1 cy

# CLR1 CY: 71 88
# CHECK: clr1 cy
# CHECK-SAME: encoding: [0x71,0x88]
clr1 cy

# NOT1 CY: 71 C0
# CHECK: not1 cy
# CHECK-SAME: encoding: [0x71,0xc0]
not1 cy

# CALL AX: 61 CA
# CHECK: call ax
# CHECK-SAME: encoding: [0x61,0xca]
call ax

# CALL BC: 61 DA
# CHECK: call bc
# CHECK-SAME: encoding: [0x61,0xda]
call bc

# CALL DE: 61 EA
# CHECK: call de
# CHECK-SAME: encoding: [0x61,0xea]
call de

# CALL HL: 61 FA
# CHECK: call hl
# CHECK-SAME: encoding: [0x61,0xfa]
call hl

# CALL !addr16: FD adrl adrh
# CHECK: call !0x1234
# CHECK-SAME: encoding: [0xfd,0x34,0x12]
call !0x1234

# CALL !!addr20: FC adrl adrh adrs
# CHECK: call !!0x12345
# CHECK-SAME: encoding: [0xfc,0x45,0x23,0x01]
call !!0x12345

# CALLT [0080h]: 61 84
# CHECK: callt [0x0080]
# CHECK-SAME: encoding: [0x61,0x84]
callt [0x0080]

# CALLT [0082h]: 61 94
# CHECK: callt [0x0082]
# CHECK-SAME: encoding: [0x61,0x94]
callt [0x0082]

# CALLT [0084h]: 61 A4
# CHECK: callt [0x0084]
# CHECK-SAME: encoding: [0x61,0xa4]
callt [0x0084]

# CALLT [0086h]: 61 B4
# CHECK: callt [0x0086]
# CHECK-SAME: encoding: [0x61,0xb4]
callt [0x0086]

# CALLT [0088h]: 61 C4
# CHECK: callt [0x0088]
# CHECK-SAME: encoding: [0x61,0xc4]
callt [0x0088]

# CALLT [008Ah]: 61 D4
# CHECK: callt [0x008a]
# CHECK-SAME: encoding: [0x61,0xd4]
callt [0x008a]

# CALLT [008Ch]: 61 E4
# CHECK: callt [0x008c]
# CHECK-SAME: encoding: [0x61,0xe4]
callt [0x008c]

# CALLT [008Eh]: 61 F4
# CHECK: callt [0x008e]
# CHECK-SAME: encoding: [0x61,0xf4]
callt [0x008e]

# CALLT [0090h]: 61 85
# CHECK: callt [0x0090]
# CHECK-SAME: encoding: [0x61,0x85]
callt [0x0090]

# CALLT [0092h]: 61 95
# CHECK: callt [0x0092]
# CHECK-SAME: encoding: [0x61,0x95]
callt [0x0092]

# CALLT [0094h]: 61 A5
# CHECK: callt [0x0094]
# CHECK-SAME: encoding: [0x61,0xa5]
callt [0x0094]

# CALLT [0096h]: 61 B5
# CHECK: callt [0x0096]
# CHECK-SAME: encoding: [0x61,0xb5]
callt [0x0096]

# CALLT [0098h]: 61 C5
# CHECK: callt [0x0098]
# CHECK-SAME: encoding: [0x61,0xc5]
callt [0x0098]

# CALLT [009Ah]: 61 D5
# CHECK: callt [0x009a]
# CHECK-SAME: encoding: [0x61,0xd5]
callt [0x009a]

# CALLT [009Ch]: 61 E5
# CHECK: callt [0x009c]
# CHECK-SAME: encoding: [0x61,0xe5]
callt [0x009c]

# CALLT [009Eh]: 61 F5
# CHECK: callt [0x009e]
# CHECK-SAME: encoding: [0x61,0xf5]
callt [0x009e]

# CALLT [00A0h]: 61 86
# CHECK: callt [0x00a0]
# CHECK-SAME: encoding: [0x61,0x86]
callt [0x00a0]

# CALLT [00A2h]: 61 96
# CHECK: callt [0x00a2]
# CHECK-SAME: encoding: [0x61,0x96]
callt [0x00a2]

# CALLT [00A4h]: 61 A6
# CHECK: callt [0x00a4]
# CHECK-SAME: encoding: [0x61,0xa6]
callt [0x00a4]

# CALLT [00A6h]: 61 B6
# CHECK: callt [0x00a6]
# CHECK-SAME: encoding: [0x61,0xb6]
callt [0x00a6]

# CALLT [00A8h]: 61 C6
# CHECK: callt [0x00a8]
# CHECK-SAME: encoding: [0x61,0xc6]
callt [0x00a8]

# CALLT [00AAh]: 61 D6
# CHECK: callt [0x00aa]
# CHECK-SAME: encoding: [0x61,0xd6]
callt [0x00aa]

# CALLT [00ACh]: 61 E6
# CHECK: callt [0x00ac]
# CHECK-SAME: encoding: [0x61,0xe6]
callt [0x00ac]

# CALLT [00AEh]: 61 F6
# CHECK: callt [0x00ae]
# CHECK-SAME: encoding: [0x61,0xf6]
callt [0x00ae]

# CALLT [00B0h]: 61 87
# CHECK: callt [0x00b0]
# CHECK-SAME: encoding: [0x61,0x87]
callt [0x00b0]

# CALLT [00B2h]: 61 97
# CHECK: callt [0x00b2]
# CHECK-SAME: encoding: [0x61,0x97]
callt [0x00b2]

# CALLT [00B4h]: 61 A7
# CHECK: callt [0x00b4]
# CHECK-SAME: encoding: [0x61,0xa7]
callt [0x00b4]

# CALLT [00B6h]: 61 B7
# CHECK: callt [0x00b6]
# CHECK-SAME: encoding: [0x61,0xb7]
callt [0x00b6]

# CALLT [00B8h]: 61 C7
# CHECK: callt [0x00b8]
# CHECK-SAME: encoding: [0x61,0xc7]
callt [0x00b8]

# CALLT [00BAh]: 61 D7
# CHECK: callt [0x00ba]
# CHECK-SAME: encoding: [0x61,0xd7]
callt [0x00ba]

# CALLT [00BCh]: 61 E7
# CHECK: callt [0x00bc]
# CHECK-SAME: encoding: [0x61,0xe7]
callt [0x00bc]

# CALLT [00BEh]: 61 F7
# CHECK: callt [0x00be]
# CHECK-SAME: encoding: [0x61,0xf7]
callt [0x00be]

# BRK : 61 CC
# CHECK: brk
# CHECK-SAME: encoding: [0x61,0xcc]
brk

# RET : D7
# CHECK: ret
# CHECK-SAME: encoding: [0xd7]
ret

# RETI : 61 FC
# CHECK: reti
# CHECK-SAME: encoding: [0x61,0xfc]
reti

# RETB : 61 EC
# CHECK: retb
# CHECK-SAME: encoding: [0x61,0xec]
retb

# PUSH PSW: 61 DD
# CHECK: push psw
# CHECK-SAME: encoding: [0x61,0xdd]
push psw

# PUSH AX: C1
# CHECK: push ax
# CHECK-SAME: encoding: [0xc1]
push ax

# PUSH BC: C3
# CHECK: push bc
# CHECK-SAME: encoding: [0xc3]
push bc

# PUSH DE: C5
# CHECK: push de
# CHECK-SAME: encoding: [0xc5]
push de

# PUSH HL: C7
# CHECK: push hl
# CHECK-SAME: encoding: [0xc7]
push hl

# POP PSW: 61 CD
# CHECK: pop psw
# CHECK-SAME: encoding: [0x61,0xcd]
pop psw

# POP AX: C0
# CHECK: pop ax
# CHECK-SAME: encoding: [0xc0]
pop ax

# POP BC: C2
# CHECK: pop bc
# CHECK-SAME: encoding: [0xc2]
pop bc

# POP DE: C4
# CHECK: pop de
# CHECK-SAME: encoding: [0xc4]
pop de

# POP HL: C6
# CHECK: pop hl
# CHECK-SAME: encoding: [0xc6]
pop hl

# MOVW SP, #word: CB F8 datal datah
# CHECK: movw sp, #13398
# CHECK-SAME: encoding: [0xcb,0xf8,0x56,0x34]
movw sp, #0x3456

# MOVW SP, AX: BE F8
# CHECK: movw sp, ax
# CHECK-SAME: encoding: [0xbe,0xf8]
movw sp, ax

# MOVW AX, SP: AE F8
# CHECK: movw ax, sp
# CHECK-SAME: encoding: [0xae,0xf8]
movw ax, sp

# MOVW BC, SP: DB F8 FF
# CHECK: movw bc, sp
# CHECK-SAME: encoding: [0xdb,0xf8,0xff]
movw bc, sp

# MOVW DE, SP: EB F8 FF
# CHECK: movw de, sp
# CHECK-SAME: encoding: [0xeb,0xf8,0xff]
movw de, sp

# MOVW HL, SP: FB F8 FF
# CHECK: movw hl, sp
# CHECK-SAME: encoding: [0xfb,0xf8,0xff]
movw hl, sp

# ADDW SP, #byte: 10 data
# CHECK: addw sp, #18
# CHECK-SAME: encoding: [0x10,0x12]
addw sp, #0x12

# SUBW SP, #byte: 20 data
# CHECK: subw sp, #18
# CHECK-SAME: encoding: [0x20,0x12]
subw sp, #0x12

# BR AX: 61 CB
# CHECK: br ax
# CHECK-SAME: encoding: [0x61,0xcb]
br ax

# BR !addr16: ED adrl adrh
# CHECK: br !0x1234
# CHECK-SAME: encoding: [0xed,0x34,0x12]
br !0x1234

# BR !!addr20: EC adrl adrh adrs
# CHECK: br !!0x12345
# CHECK-SAME: encoding: [0xec,0x45,0x23,0x01]
br !!0x12345

# SKC : 61 C8
# CHECK: skc
# CHECK-SAME: encoding: [0x61,0xc8]
skc

# SKNC : 61 D8
# CHECK: sknc
# CHECK-SAME: encoding: [0x61,0xd8]
sknc

# SKZ : 61 E8
# CHECK: skz
# CHECK-SAME: encoding: [0x61,0xe8]
skz

# SKNZ : 61 F8
# CHECK: sknz
# CHECK-SAME: encoding: [0x61,0xf8]
sknz

# SKH : 61 E3
# CHECK: skh
# CHECK-SAME: encoding: [0x61,0xe3]
skh

# SKNH : 61 F3
# CHECK: sknh
# CHECK-SAME: encoding: [0x61,0xf3]
sknh

# SEL RB0: 61 CF
# CHECK: sel rb0
# CHECK-SAME: encoding: [0x61,0xcf]
sel rb0

# SEL RB1: 61 DF
# CHECK: sel rb1
# CHECK-SAME: encoding: [0x61,0xdf]
sel rb1

# SEL RB2: 61 EF
# CHECK: sel rb2
# CHECK-SAME: encoding: [0x61,0xef]
sel rb2

# SEL RB3: 61 FF
# CHECK: sel rb3
# CHECK-SAME: encoding: [0x61,0xff]
sel rb3

# NOP : 00
# CHECK: nop
# CHECK-SAME: encoding: [0x00]
nop

# EI : 71 7A FA
# CHECK: ei
# CHECK-SAME: encoding: [0x71,0x7a,0xfa]
ei

# DI : 71 7B FA
# CHECK: di
# CHECK-SAME: encoding: [0x71,0x7b,0xfa]
di

# HALT : 61 ED
# CHECK: halt
# CHECK-SAME: encoding: [0x61,0xed]
halt

# STOP : 61 FD
# CHECK: stop
# CHECK-SAME: encoding: [0x61,0xfd]
stop

