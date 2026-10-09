# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: xor1 cy, 0xffe20.0                   ; encoding: [0x71,0x07,0x20]
xor1 CY, 0xFFE20.0

# CHECK-INST: xor1 cy, 0xffe20.1                   ; encoding: [0x71,0x17,0x20]
xor1 CY, 0xFFE20.1

# CHECK-INST: xor1 cy, 0xffe20.2                   ; encoding: [0x71,0x27,0x20]
xor1 CY, 0xFFE20.2

# CHECK-INST: xor1 cy, 0xffe20.3                   ; encoding: [0x71,0x37,0x20]
xor1 CY, 0xFFE20.3

# CHECK-INST: xor1 cy, 0xffe20.4                   ; encoding: [0x71,0x47,0x20]
xor1 CY, 0xFFE20.4

# CHECK-INST: xor1 cy, 0xffe20.5                   ; encoding: [0x71,0x57,0x20]
xor1 CY, 0xFFE20.5

# CHECK-INST: xor1 cy, 0xffe20.6                   ; encoding: [0x71,0x67,0x20]
xor1 CY, 0xFFE20.6

# CHECK-INST: xor1 cy, 0xffe20.7                   ; encoding: [0x71,0x77,0x20]
xor1 CY, 0xFFE20.7



# CHECK-INST: xor1 cy, saddr+0.0                      ; encoding: [0x71,0x07,A]
xor1 CY, saddr.0

# CHECK-INST: xor1 cy, saddr+0.1                      ; encoding: [0x71,0x17,A]
xor1 CY, saddr.1

# CHECK-INST: xor1 cy, saddr+0.2                      ; encoding: [0x71,0x27,A]
xor1 CY, saddr.2

# CHECK-INST: xor1 cy, saddr+0.3                      ; encoding: [0x71,0x37,A]
xor1 CY, saddr.3

# CHECK-INST: xor1 cy, saddr+0.4                      ; encoding: [0x71,0x47,A]
xor1 CY, saddr.4

# CHECK-INST: xor1 cy, saddr+0.5                      ; encoding: [0x71,0x57,A]
xor1 CY, saddr.5

# CHECK-INST: xor1 cy, saddr+0.6                      ; encoding: [0x71,0x67,A]
xor1 CY, saddr.6

# CHECK-INST: xor1 cy, saddr+0.7                      ; encoding: [0x71,0x77,A]
xor1 CY, saddr.7



# CHECK-INST: xor1 cy, 0xfff20.0                      ; encoding: [0x71,0x0f,0x20]
xor1 CY, 0xFFF20.0

# CHECK-INST: xor1 cy, 0xfff20.1                      ; encoding: [0x71,0x1f,0x20]
xor1 CY, 0xFFF20.1

# CHECK-INST: xor1 cy, 0xfff20.2                      ; encoding: [0x71,0x2f,0x20]
xor1 CY, 0xFFF20.2

# CHECK-INST: xor1 cy, 0xfff20.3                      ; encoding: [0x71,0x3f,0x20]
xor1 CY, 0xFFF20.3

# CHECK-INST: xor1 cy, 0xfff20.4                      ; encoding: [0x71,0x4f,0x20]
xor1 CY, 0xFFF20.4

# CHECK-INST: xor1 cy, 0xfff20.5                      ; encoding: [0x71,0x5f,0x20]
xor1 CY, 0xFFF20.5

# CHECK-INST: xor1 cy, 0xfff20.6                      ; encoding: [0x71,0x6f,0x20]
xor1 CY, 0xFFF20.6

# CHECK-INST: xor1 cy, 0xfff20.7                      ; encoding: [0x71,0x7f,0x20]
xor1 CY, 0xFFF20.7



# CHECK-INST: xor1 cy, a.0                            ; encoding: [0x71,0x8f]
xor1 CY, A.0

# CHECK-INST: xor1 cy, a.1                            ; encoding: [0x71,0x9f]
xor1 CY, A.1

# CHECK-INST: xor1 cy, a.2                            ; encoding: [0x71,0xaf]
xor1 CY, A.2

# CHECK-INST: xor1 cy, a.3                            ; encoding: [0x71,0xbf]
xor1 CY, A.3

# CHECK-INST: xor1 cy, a.4                            ; encoding: [0x71,0xcf]
xor1 CY, A.4

# CHECK-INST: xor1 cy, a.5                            ; encoding: [0x71,0xdf]
xor1 CY, A.5

# CHECK-INST: xor1 cy, a.6                            ; encoding: [0x71,0xef]
xor1 CY, A.6

# CHECK-INST: xor1 cy, a.7                            ; encoding: [0x71,0xff]
xor1 CY, A.7



# CHECK-INST: xor1 cy, psw.0                      ; encoding: [0x71,0x0f,0xfa]
xor1 CY, PSW.0

# CHECK-INST: xor1 cy, psw.1                      ; encoding: [0x71,0x1f,0xfa]
xor1 CY, PSW.1

# CHECK-INST: xor1 cy, psw.2                      ; encoding: [0x71,0x2f,0xfa]
xor1 CY, PSW.2

# CHECK-INST: xor1 cy, psw.3                      ; encoding: [0x71,0x3f,0xfa]
xor1 CY, PSW.3

# CHECK-INST: xor1 cy, psw.4                      ; encoding: [0x71,0x4f,0xfa]
xor1 CY, PSW.4

# CHECK-INST: xor1 cy, psw.5                      ; encoding: [0x71,0x5f,0xfa]
xor1 CY, PSW.5

# CHECK-INST: xor1 cy, psw.6                      ; encoding: [0x71,0x6f,0xfa]
xor1 CY, PSW.6

# CHECK-INST: xor1 cy, psw.7                      ; encoding: [0x71,0x7f,0xfa]
xor1 CY, PSW.7



# CHECK-INST: xor1 cy, [hl].0                         ; encoding: [0x71,0x87]
xor1 CY, [HL].0

# CHECK-INST: xor1 cy, [hl].1                         ; encoding: [0x71,0x97]
xor1 CY, [HL].1

# CHECK-INST: xor1 cy, [hl].2                         ; encoding: [0x71,0xa7]
xor1 CY, [HL].2

# CHECK-INST: xor1 cy, [hl].3                         ; encoding: [0x71,0xb7]
xor1 CY, [HL].3

# CHECK-INST: xor1 cy, [hl].4                         ; encoding: [0x71,0xc7]
xor1 CY, [HL].4

# CHECK-INST: xor1 cy, [hl].5                         ; encoding: [0x71,0xd7]
xor1 CY, [HL].5

# CHECK-INST: xor1 cy, [hl].6                         ; encoding: [0x71,0xe7]
xor1 CY, [HL].6

# CHECK-INST: xor1 cy, [hl].7                         ; encoding: [0x71,0xf7]
xor1 CY, [HL].7



# CHECK-INST: xor1 cy, es:[hl].0                      ; encoding: [0x11,0x71,0x87]
xor1 CY, ES:[HL].0

# CHECK-INST: xor1 cy, es:[hl].1                      ; encoding: [0x11,0x71,0x97]
xor1 CY, ES:[HL].1

# CHECK-INST: xor1 cy, es:[hl].2                      ; encoding: [0x11,0x71,0xa7]
xor1 CY, ES:[HL].2

# CHECK-INST: xor1 cy, es:[hl].3                      ; encoding: [0x11,0x71,0xb7]
xor1 CY, ES:[HL].3

# CHECK-INST: xor1 cy, es:[hl].4                      ; encoding: [0x11,0x71,0xc7]
xor1 CY, ES:[HL].4

# CHECK-INST: xor1 cy, es:[hl].5                      ; encoding: [0x11,0x71,0xd7]
xor1 CY, ES:[HL].5

# CHECK-INST: xor1 cy, es:[hl].6                      ; encoding: [0x11,0x71,0xe7]
xor1 CY, ES:[HL].6

# CHECK-INST: xor1 cy, es:[hl].7                      ; encoding: [0x11,0x71,0xf7]
xor1 CY, ES:[HL].7
