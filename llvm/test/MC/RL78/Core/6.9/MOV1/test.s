# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s


# CHECK-INST: mov1 cy, 0xffe20.0                   ; encoding: [0x71,0x04,0x20]
mov1 CY, 0xFFE20.0

# CHECK-INST: mov1 cy, 0xffe20.1                   ; encoding: [0x71,0x14,0x20]
mov1 CY, 0xFFE20.1

# CHECK-INST: mov1 cy, 0xffe20.2                   ; encoding: [0x71,0x24,0x20]
mov1 CY, 0xFFE20.2

# CHECK-INST: mov1 cy, 0xffe20.3                   ; encoding: [0x71,0x34,0x20]
mov1 CY, 0xFFE20.3

# CHECK-INST: mov1 cy, 0xffe20.4                   ; encoding: [0x71,0x44,0x20]
mov1 CY, 0xFFE20.4

# CHECK-INST: mov1 cy, 0xffe20.5                   ; encoding: [0x71,0x54,0x20]
mov1 CY, 0xFFE20.5

# CHECK-INST: mov1 cy, 0xffe20.6                   ; encoding: [0x71,0x64,0x20]
mov1 CY, 0xFFE20.6

# CHECK-INST: mov1 cy, 0xffe20.7                   ; encoding: [0x71,0x74,0x20]
mov1 CY, 0xFFE20.7



# CHECK-INST: mov1 cy, saddr+0.0                   ; encoding: [0x71,0x04,A]
mov1 CY, saddr.0

# CHECK-INST: mov1 cy, saddr+0.1                   ; encoding: [0x71,0x14,A]
mov1 CY, saddr.1

# CHECK-INST: mov1 cy, saddr+0.2                   ; encoding: [0x71,0x24,A]
mov1 CY, saddr.2

# CHECK-INST: mov1 cy, saddr+0.3                   ; encoding: [0x71,0x34,A]
mov1 CY, saddr.3

# CHECK-INST: mov1 cy, saddr+0.4                   ; encoding: [0x71,0x44,A]
mov1 CY, saddr.4

# CHECK-INST: mov1 cy, saddr+0.5                   ; encoding: [0x71,0x54,A]
mov1 CY, saddr.5

# CHECK-INST: mov1 cy, saddr+0.6                   ; encoding: [0x71,0x64,A]
mov1 CY, saddr.6

# CHECK-INST: mov1 cy, saddr+0.7                   ; encoding: [0x71,0x74,A]
mov1 CY, saddr.7



# CHECK-INST: mov1 cy, 0xfff20.0                   ; encoding: [0x71,0x0c,0x20]
mov1 CY, 0xFFF20.0

# CHECK-INST: mov1 cy, 0xfff20.1                   ; encoding: [0x71,0x1c,0x20]
mov1 CY, 0xFFF20.1

# CHECK-INST: mov1 cy, 0xfff20.2                   ; encoding: [0x71,0x2c,0x20]
mov1 CY, 0xFFF20.2

# CHECK-INST: mov1 cy, 0xfff20.3                   ; encoding: [0x71,0x3c,0x20]
mov1 CY, 0xFFF20.3

# CHECK-INST: mov1 cy, 0xfff20.4                   ; encoding: [0x71,0x4c,0x20]
mov1 CY, 0xFFF20.4

# CHECK-INST: mov1 cy, 0xfff20.5                   ; encoding: [0x71,0x5c,0x20]
mov1 CY, 0xFFF20.5

# CHECK-INST: mov1 cy, 0xfff20.6                   ; encoding: [0x71,0x6c,0x20]
mov1 CY, 0xFFF20.6

# CHECK-INST: mov1 cy, 0xfff20.7                   ; encoding: [0x71,0x7c,0x20]
mov1 CY, 0xFFF20.7



# CHECK-INST: mov1 cy, a.0                   ; encoding: [0x71,0x8c]
mov1 CY, A.0

# CHECK-INST: mov1 cy, a.1                   ; encoding: [0x71,0x9c]
mov1 CY, A.1

# CHECK-INST: mov1 cy, a.2                   ; encoding: [0x71,0xac]
mov1 CY, A.2

# CHECK-INST: mov1 cy, a.3                   ; encoding: [0x71,0xbc]
mov1 CY, A.3

# CHECK-INST: mov1 cy, a.4                   ; encoding: [0x71,0xcc]
mov1 CY, A.4

# CHECK-INST: mov1 cy, a.5                   ; encoding: [0x71,0xdc]
mov1 CY, A.5

# CHECK-INST: mov1 cy, a.6                   ; encoding: [0x71,0xec]
mov1 CY, A.6

# CHECK-INST: mov1 cy, a.7                   ; encoding: [0x71,0xfc]
mov1 CY, A.7



# CHECK-INST: mov1 cy, psw.0                      ; encoding: [0x71,0x0c,0xfa]
mov1 CY, PSW.0

# CHECK-INST: mov1 cy, psw.1                      ; encoding: [0x71,0x1c,0xfa]
mov1 CY, PSW.1

# CHECK-INST: mov1 cy, psw.2                      ; encoding: [0x71,0x2c,0xfa]
mov1 CY, PSW.2

# CHECK-INST: mov1 cy, psw.3                      ; encoding: [0x71,0x3c,0xfa]
mov1 CY, PSW.3

# CHECK-INST: mov1 cy, psw.4                      ; encoding: [0x71,0x4c,0xfa]
mov1 CY, PSW.4

# CHECK-INST: mov1 cy, psw.5                      ; encoding: [0x71,0x5c,0xfa]
mov1 CY, PSW.5

# CHECK-INST: mov1 cy, psw.6                      ; encoding: [0x71,0x6c,0xfa]
mov1 CY, PSW.6

# CHECK-INST: mov1 cy, psw.7                      ; encoding: [0x71,0x7c,0xfa]
mov1 CY, PSW.7



# CHECK-INST: mov1 cy, [hl].0                        ; encoding: [0x71,0x84]
mov1 CY, [HL].0

# CHECK-INST: mov1 cy, [hl].1                        ; encoding: [0x71,0x94]
mov1 CY, [HL].1

# CHECK-INST: mov1 cy, [hl].2                        ; encoding: [0x71,0xa4]
mov1 CY, [HL].2

# CHECK-INST: mov1 cy, [hl].3                        ; encoding: [0x71,0xb4]
mov1 CY, [HL].3

# CHECK-INST: mov1 cy, [hl].4                        ; encoding: [0x71,0xc4]
mov1 CY, [HL].4

# CHECK-INST: mov1 cy, [hl].5                        ; encoding: [0x71,0xd4]
mov1 CY, [HL].5

# CHECK-INST: mov1 cy, [hl].6                        ; encoding: [0x71,0xe4]
mov1 CY, [HL].6

# CHECK-INST: mov1 cy, [hl].7                        ; encoding: [0x71,0xf4]
mov1 CY, [HL].7



# CHECK-INST: mov1 0xfff00.0, cy                   ; encoding: [0x71,0x01,0x00]
mov1 0xFFF00.0, CY

# CHECK-INST: mov1 0xfff00.1, cy                   ; encoding: [0x71,0x11,0x00]
mov1 0xFFF00.1, CY

# CHECK-INST: mov1 0xfff00.2, cy                   ; encoding: [0x71,0x21,0x00]
mov1 0xFFF00.2, CY

# CHECK-INST: mov1 0xfff00.3, cy                   ; encoding: [0x71,0x31,0x00]
mov1 0xFFF00.3, CY

# CHECK-INST: mov1 0xfff00.4, cy                   ; encoding: [0x71,0x41,0x00]
mov1 0xFFF00.4, CY

# CHECK-INST: mov1 0xfff00.5, cy                   ; encoding: [0x71,0x51,0x00]
mov1 0xFFF00.5, CY

# CHECK-INST: mov1 0xfff00.6, cy                   ; encoding: [0x71,0x61,0x00]
mov1 0xFFF00.6, CY

# CHECK-INST: mov1 0xfff00.7, cy                   ; encoding: [0x71,0x71,0x00]
mov1 0xFFF00.7, CY



# CHECK-INST: mov1 0xfff20.0, cy                   ; encoding: [0x71,0x09,0x20]
mov1 0xFFF20.0, CY

# CHECK-INST: mov1 0xfff20.1, cy                   ; encoding: [0x71,0x19,0x20]
mov1 0xFFF20.1, CY

# CHECK-INST: mov1 0xfff20.2, cy                   ; encoding: [0x71,0x29,0x20]
mov1 0xFFF20.2, CY

# CHECK-INST: mov1 0xfff20.3, cy                   ; encoding: [0x71,0x39,0x20]
mov1 0xFFF20.3, CY

# CHECK-INST: mov1 0xfff20.4, cy                   ; encoding: [0x71,0x49,0x20]
mov1 0xFFF20.4, CY

# CHECK-INST: mov1 0xfff20.5, cy                   ; encoding: [0x71,0x59,0x20]
mov1 0xFFF20.5, CY

# CHECK-INST: mov1 0xfff20.6, cy                   ; encoding: [0x71,0x69,0x20]
mov1 0xFFF20.6, CY

# CHECK-INST: mov1 0xfff20.7, cy                   ; encoding: [0x71,0x79,0x20]
mov1 0xFFF20.7, CY



# CHECK-INST: mov1 a.0, cy                            ; encoding: [0x71,0x89]
mov1 A.0, CY

# CHECK-INST: mov1 a.1, cy                            ; encoding: [0x71,0x99]
mov1 A.1, CY

# CHECK-INST: mov1 a.2, cy                            ; encoding: [0x71,0xa9]
mov1 A.2, CY

# CHECK-INST: mov1 a.3, cy                            ; encoding: [0x71,0xb9]
mov1 A.3, CY

# CHECK-INST: mov1 a.4, cy                            ; encoding: [0x71,0xc9]
mov1 A.4, CY

# CHECK-INST: mov1 a.5, cy                            ; encoding: [0x71,0xd9]
mov1 A.5, CY

# CHECK-INST: mov1 a.6, cy                            ; encoding: [0x71,0xe9]
mov1 A.6, CY

# CHECK-INST: mov1 a.7, cy                            ; encoding: [0x71,0xf9]
mov1 A.7, CY



# CHECK-INST: mov1 psw.0, cy                      ; encoding: [0x71,0x09,0xfa]
mov1 PSW.0, CY

# CHECK-INST: mov1 psw.1, cy                   ; encoding: [0x71,0x19,0xfa]
mov1 PSW.1, CY

# CHECK-INST: mov1 psw.2, cy                   ; encoding: [0x71,0x29,0xfa]
mov1 PSW.2, CY

# CHECK-INST: mov1 psw.3, cy                   ; encoding: [0x71,0x39,0xfa]
mov1 PSW.3, CY

# CHECK-INST: mov1 psw.4, cy                   ; encoding: [0x71,0x49,0xfa]
mov1 PSW.4, CY

# CHECK-INST: mov1 psw.5, cy                   ; encoding: [0x71,0x59,0xfa]
mov1 PSW.5, CY

# CHECK-INST: mov1 psw.6, cy                   ; encoding: [0x71,0x69,0xfa]
mov1 PSW.6, CY

# CHECK-INST: mov1 psw.7, cy                   ; encoding: [0x71,0x79,0xfa]
mov1 PSW.7, CY



# CHECK-INST: mov1 [hl].0, cy                         ; encoding: [0x71,0x81]
mov1 [HL].0, CY

# CHECK-INST: mov1 [hl].1, cy                   ; encoding: [0x71,0x91]
mov1 [HL].1, CY

# CHECK-INST: mov1 [hl].2, cy                   ; encoding: [0x71,0xa1]
mov1 [HL].2, CY

# CHECK-INST: mov1 [hl].3, cy                   ; encoding: [0x71,0xb1]
mov1 [HL].3, CY

# CHECK-INST: mov1 [hl].4, cy                   ; encoding: [0x71,0xc1]
mov1 [HL].4, CY

# CHECK-INST: mov1 [hl].5, cy                   ; encoding: [0x71,0xd1]
mov1 [HL].5, CY

# CHECK-INST: mov1 [hl].6, cy                   ; encoding: [0x71,0xe1]
mov1 [HL].6, CY

# CHECK-INST: mov1 [hl].7, cy                   ; encoding: [0x71,0xf1]
mov1 [HL].7, CY



# CHECK-INST: mov1 cy, es:[hl].0                      ; encoding: [0x11,0x71,0x84]
mov1 CY, ES:[HL].0

# CHECK-INST: mov1 cy, es:[hl].1                   ; encoding: [0x11,0x71,0x94]
mov1 CY, ES:[HL].1

# CHECK-INST: mov1 cy, es:[hl].2                   ; encoding: [0x11,0x71,0xa4]
mov1 CY, ES:[HL].2

# CHECK-INST: mov1 cy, es:[hl].3                   ; encoding: [0x11,0x71,0xb4]
mov1 CY, ES:[HL].3

# CHECK-INST: mov1 cy, es:[hl].4                   ; encoding: [0x11,0x71,0xc4]
mov1 CY, ES:[HL].4

# CHECK-INST: mov1 cy, es:[hl].5                   ; encoding: [0x11,0x71,0xd4]
mov1 CY, ES:[HL].5

# CHECK-INST: mov1 cy, es:[hl].6                   ; encoding: [0x11,0x71,0xe4]
mov1 CY, ES:[HL].6

# CHECK-INST: mov1 cy, es:[hl].7                   ; encoding: [0x11,0x71,0xf4]
mov1 CY, ES:[HL].7



# CHECK-INST: mov1 es:[hl].0, cy                      ; encoding: [0x11,0x71,0x81]
mov1 ES:[HL].0, CY

# CHECK-INST: mov1 es:[hl].1, cy                      ; encoding: [0x11,0x71,0x91]
mov1 ES:[HL].1, CY

# CHECK-INST: mov1 es:[hl].2, cy                      ; encoding: [0x11,0x71,0xa1]
mov1 ES:[HL].2, CY

# CHECK-INST: mov1 es:[hl].3, cy                      ; encoding: [0x11,0x71,0xb1]
mov1 ES:[HL].3, CY

# CHECK-INST: mov1 es:[hl].4, cy                      ; encoding: [0x11,0x71,0xc1]
mov1 ES:[HL].4, CY

# CHECK-INST: mov1 es:[hl].5, cy                      ; encoding: [0x11,0x71,0xd1]
mov1 ES:[HL].5, CY

# CHECK-INST: mov1 es:[hl].6, cy                      ; encoding: [0x11,0x71,0xe1]
mov1 ES:[HL].6, CY

# CHECK-INST: mov1 es:[hl].7, cy                      ; encoding: [0x11,0x71,0xf1]
mov1 ES:[HL].7, CY
