# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: clr1 0xffe20.0                   ; encoding: [0x71,0x03,0x20]
clr1 0xFFE20.0

# CHECK-INST: clr1 0xffe20.1                   ; encoding: [0x71,0x13,0x20]
clr1 0xFFE20.1

# CHECK-INST: clr1 0xffe20.2                   ; encoding: [0x71,0x23,0x20]
clr1 0xFFE20.2

# CHECK-INST: clr1 0xffe20.3                   ; encoding: [0x71,0x33,0x20]
clr1 0xFFE20.3

# CHECK-INST: clr1 0xffe20.4                   ; encoding: [0x71,0x43,0x20]
clr1 0xFFE20.4

# CHECK-INST: clr1 0xffe20.5                   ; encoding: [0x71,0x53,0x20]
clr1 0xFFE20.5

# CHECK-INST: clr1 0xffe20.6                   ; encoding: [0x71,0x63,0x20]
clr1 0xFFE20.6

# CHECK-INST: clr1 0xffe20.7                   ; encoding: [0x71,0x73,0x20]
clr1 0xFFE20.7



# CHECK-INST: clr1 saddr+0.0                      ; encoding: [0x71,0x03,A]
clr1 saddr.0

# CHECK-INST: clr1 saddr+0.1                      ; encoding: [0x71,0x13,A]
clr1 saddr.1

# CHECK-INST: clr1 saddr+0.2                      ; encoding: [0x71,0x23,A]
clr1 saddr.2

# CHECK-INST: clr1 saddr+0.3                      ; encoding: [0x71,0x33,A]
clr1 saddr.3

# CHECK-INST: clr1 saddr+0.4                      ; encoding: [0x71,0x43,A]
clr1 saddr.4

# CHECK-INST: clr1 saddr+0.5                      ; encoding: [0x71,0x53,A]
clr1 saddr.5

# CHECK-INST: clr1 saddr+0.6                      ; encoding: [0x71,0x63,A]
clr1 saddr.6

# CHECK-INST: clr1 saddr+0.7                      ; encoding: [0x71,0x73,A]
clr1 saddr.7



# CHECK-INST: clr1 0xfff20.0                      ; encoding: [0x71,0x0b,0x20]
clr1 0xFFF20.0

# CHECK-INST: clr1 0xfff20.1                      ; encoding: [0x71,0x1b,0x20]
clr1 0xFFF20.1

# CHECK-INST: clr1 0xfff20.2                      ; encoding: [0x71,0x2b,0x20]
clr1 0xFFF20.2

# CHECK-INST: clr1 0xfff20.3                      ; encoding: [0x71,0x3b,0x20]
clr1 0xFFF20.3

# CHECK-INST: clr1 0xfff20.4                      ; encoding: [0x71,0x4b,0x20]
clr1 0xFFF20.4

# CHECK-INST: clr1 0xfff20.5                      ; encoding: [0x71,0x5b,0x20]
clr1 0xFFF20.5

# CHECK-INST: clr1 0xfff20.6                      ; encoding: [0x71,0x6b,0x20]
clr1 0xFFF20.6

# CHECK-INST: clr1 0xfff20.7                      ; encoding: [0x71,0x7b,0x20]
clr1 0xFFF20.7



# CHECK-INST: clr1 a.0                            ; encoding: [0x71,0x8b]
clr1 A.0

# CHECK-INST: clr1 a.1                            ; encoding: [0x71,0x9b]
clr1 A.1

# CHECK-INST: clr1 a.2                            ; encoding: [0x71,0xab]
clr1 A.2

# CHECK-INST: clr1 a.3                            ; encoding: [0x71,0xbb]
clr1 A.3

# CHECK-INST: clr1 a.4                            ; encoding: [0x71,0xcb]
clr1 A.4

# CHECK-INST: clr1 a.5                            ; encoding: [0x71,0xdb]
clr1 A.5

# CHECK-INST: clr1 a.6                            ; encoding: [0x71,0xeb]
clr1 A.6

# CHECK-INST: clr1 a.7                            ; encoding: [0x71,0xfb]
clr1 A.7



# CHECK-INST: clr1 !0x1111.0                         ; encoding: [0x71,0x08,A,A]
clr1 !0x1111.0

# CHECK-INST: clr1 !0x1111.1                         ; encoding: [0x71,0x18,A,A]
clr1 !0x1111.1

# CHECK-INST: clr1 !0x1111.2                         ; encoding: [0x71,0x28,A,A]
clr1 !0x1111.2

# CHECK-INST: clr1 !0x1111.3                         ; encoding: [0x71,0x38,A,A]
clr1 !0x1111.3

# CHECK-INST: clr1 !0x1111.4                         ; encoding: [0x71,0x48,A,A]
clr1 !0x1111.4

# CHECK-INST: clr1 !0x1111.5                         ; encoding: [0x71,0x58,A,A]
clr1 !0x1111.5

# CHECK-INST: clr1 !0x1111.6                         ; encoding: [0x71,0x68,A,A]
clr1 !0x1111.6

# CHECK-INST: clr1 !0x1111.7                         ; encoding: [0x71,0x78,A,A]
clr1 !0x1111.7


# CHECK-INST: clr1 0xffffa.0                      ; encoding: [0x71,0x0b,0xfa]
clr1 PSW.0

# CHECK-INST: clr1 0xffffa.1                      ; encoding: [0x71,0x1b,0xfa]
clr1 PSW.1

# CHECK-INST: clr1 0xffffa.2                      ; encoding: [0x71,0x2b,0xfa]
clr1 PSW.2

# CHECK-INST: clr1 0xffffa.3                      ; encoding: [0x71,0x3b,0xfa]
clr1 PSW.3

# CHECK-INST: clr1 0xffffa.4                      ; encoding: [0x71,0x4b,0xfa]
clr1 PSW.4

# CHECK-INST: clr1 0xffffa.5                      ; encoding: [0x71,0x5b,0xfa]
clr1 PSW.5

# CHECK-INST: clr1 0xffffa.6                      ; encoding: [0x71,0x6b,0xfa]
clr1 PSW.6

# CHECK-INST: clr1 0xffffa.7                      ; encoding: [0x71,0x7b,0xfa]
clr1 PSW.7



# CHECK-INST: clr1 [hl].0                         ; encoding: [0x71,0x83]
clr1 [HL].0

# CHECK-INST: clr1 [hl].1                         ; encoding: [0x71,0x93]
clr1 [HL].1

# CHECK-INST: clr1 [hl].2                         ; encoding: [0x71,0xa3]
clr1 [HL].2

# CHECK-INST: clr1 [hl].3                         ; encoding: [0x71,0xb3]
clr1 [HL].3

# CHECK-INST: clr1 [hl].4                         ; encoding: [0x71,0xc3]
clr1 [HL].4

# CHECK-INST: clr1 [hl].5                         ; encoding: [0x71,0xd3]
clr1 [HL].5

# CHECK-INST: clr1 [hl].6                         ; encoding: [0x71,0xe3]
clr1 [HL].6

# CHECK-INST: clr1 [hl].7                         ; encoding: [0x71,0xf3]
clr1 [HL].7



# CHECK-INST: clr1 es:!0x1111.0                         ; encoding: [0x11,0x71,0x08,A,A]
clr1 ES:!0x1111.0

# CHECK-INST: clr1 es:!0x1111.1                         ; encoding: [0x11,0x71,0x18,A,A]
clr1 ES:!0x1111.1

# CHECK-INST: clr1 es:!0x1111.2                         ; encoding: [0x11,0x71,0x28,A,A]
clr1 ES:!0x1111.2

# CHECK-INST: clr1 es:!0x1111.3                         ; encoding: [0x11,0x71,0x38,A,A]
clr1 ES:!0x1111.3
 
# CHECK-INST: clr1 es:!0x1111.4                         ; encoding: [0x11,0x71,0x48,A,A]
clr1 ES:!0x1111.4

# CHECK-INST: clr1 es:!0x1111.5                         ; encoding: [0x11,0x71,0x58,A,A]
clr1 ES:!0x1111.5

# CHECK-INST: clr1 es:!0x1111.6                         ; encoding: [0x11,0x71,0x68,A,A]
clr1 ES:!0x1111.6

# CHECK-INST: clr1 es:!0x1111.7                         ; encoding: [0x11,0x71,0x78,A,A]
clr1 ES:!0x1111.7



# CHECK-INST: clr1 es:[hl].0                      ; encoding: [0x11,0x71,0x83]
clr1 ES:[HL].0

# CHECK-INST: clr1 es:[hl].1                      ; encoding: [0x11,0x71,0x93]
clr1 ES:[HL].1

# CHECK-INST: clr1 es:[hl].2                      ; encoding: [0x11,0x71,0xa3]
clr1 ES:[HL].2

# CHECK-INST: clr1 es:[hl].3                      ; encoding: [0x11,0x71,0xb3]
clr1 ES:[HL].3

# CHECK-INST: clr1 es:[hl].4                      ; encoding: [0x11,0x71,0xc3]
clr1 ES:[HL].4

# CHECK-INST: clr1 es:[hl].5                      ; encoding: [0x11,0x71,0xd3]
clr1 ES:[HL].5

# CHECK-INST: clr1 es:[hl].6                      ; encoding: [0x11,0x71,0xe3]
clr1 ES:[HL].6

# CHECK-INST: clr1 es:[hl].7                      ; encoding: [0x11,0x71,0xf3]
clr1 ES:[HL].7


# CHECK-INST: clr1 cy                                 ; encoding: [0x71,0x88]
clr1 CY
