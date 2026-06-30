# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: set1 0xffe20.0                   ; encoding: [0x71,0x02,0x20]
set1 0xFFE20.0

# CHECK-INST: set1 0xffe20.1                   ; encoding: [0x71,0x12,0x20]
set1 0xFFE20.1

# CHECK-INST: set1 0xffe20.2                   ; encoding: [0x71,0x22,0x20]
set1 0xFFE20.2

# CHECK-INST: set1 0xffe20.3                   ; encoding: [0x71,0x32,0x20]
set1 0xFFE20.3

# CHECK-INST: set1 0xffe20.4                   ; encoding: [0x71,0x42,0x20]
set1 0xFFE20.4

# CHECK-INST: set1 0xffe20.5                   ; encoding: [0x71,0x52,0x20]
set1 0xFFE20.5

# CHECK-INST: set1 0xffe20.6                   ; encoding: [0x71,0x62,0x20]
set1 0xFFE20.6

# CHECK-INST: set1 0xffe20.7                   ; encoding: [0x71,0x72,0x20]
set1 0xFFE20.7



# CHECK-INST: set1 saddr+0.0                      ; encoding: [0x71,0x02,A]
set1 saddr.0

# CHECK-INST: set1 saddr+0.1                      ; encoding: [0x71,0x12,A]
set1 saddr.1

# CHECK-INST: set1 saddr+0.2                      ; encoding: [0x71,0x22,A]
set1 saddr.2

# CHECK-INST: set1 saddr+0.3                      ; encoding: [0x71,0x32,A]
set1 saddr.3

# CHECK-INST: set1 saddr+0.4                      ; encoding: [0x71,0x42,A]
set1 saddr.4

# CHECK-INST: set1 saddr+0.5                      ; encoding: [0x71,0x52,A]
set1 saddr.5

# CHECK-INST: set1 saddr+0.6                      ; encoding: [0x71,0x62,A]
set1 saddr.6

# CHECK-INST: set1 saddr+0.7                      ; encoding: [0x71,0x72,A]
set1 saddr.7



# CHECK-INST: set1 0xfff20.0                      ; encoding: [0x71,0x0a,0x20]
set1 0xFFF20.0

# CHECK-INST: set1 0xfff20.1                      ; encoding: [0x71,0x1a,0x20]
set1 0xFFF20.1

# CHECK-INST: set1 0xfff20.2                      ; encoding: [0x71,0x2a,0x20]
set1 0xFFF20.2

# CHECK-INST: set1 0xfff20.3                      ; encoding: [0x71,0x3a,0x20]
set1 0xFFF20.3

# CHECK-INST: set1 0xfff20.4                      ; encoding: [0x71,0x4a,0x20]
set1 0xFFF20.4

# CHECK-INST: set1 0xfff20.5                      ; encoding: [0x71,0x5a,0x20]
set1 0xFFF20.5

# CHECK-INST: set1 0xfff20.6                      ; encoding: [0x71,0x6a,0x20]
set1 0xFFF20.6

# CHECK-INST: set1 0xfff20.7                      ; encoding: [0x71,0x7a,0x20]
set1 0xFFF20.7



# CHECK-INST: set1 a.0                            ; encoding: [0x71,0x8a]
set1 A.0

# CHECK-INST: set1 a.1                            ; encoding: [0x71,0x9a]
set1 A.1

# CHECK-INST: set1 a.2                            ; encoding: [0x71,0xaa]
set1 A.2

# CHECK-INST: set1 a.3                            ; encoding: [0x71,0xba]
set1 A.3

# CHECK-INST: set1 a.4                            ; encoding: [0x71,0xca]
set1 A.4

# CHECK-INST: set1 a.5                            ; encoding: [0x71,0xda]
set1 A.5

# CHECK-INST: set1 a.6                            ; encoding: [0x71,0xea]
set1 A.6

# CHECK-INST: set1 a.7                            ; encoding: [0x71,0xfa]
set1 A.7



# CHECK-INST: set1 !0x1111.0                         ; encoding: [0x71,0x00,A,A]
set1 !0x1111.0

# CHECK-INST: set1 !0x1111.1                         ; encoding: [0x71,0x10,A,A]
set1 !0x1111.1

# CHECK-INST: set1 !0x1111.2                         ; encoding: [0x71,0x20,A,A]
set1 !0x1111.2

# CHECK-INST: set1 !0x1111.3                         ; encoding: [0x71,0x30,A,A]
set1 !0x1111.3

# CHECK-INST: set1 !0x1111.4                         ; encoding: [0x71,0x40,A,A]
set1 !0x1111.4

# CHECK-INST: set1 !0x1111.5                         ; encoding: [0x71,0x50,A,A]
set1 !0x1111.5

# CHECK-INST: set1 !0x1111.6                         ; encoding: [0x71,0x60,A,A]
set1 !0x1111.6

# CHECK-INST: set1 !0x1111.7                         ; encoding: [0x71,0x70,A,A]
set1 !0x1111.7


# CHECK-INST: set1 0xffffa.0                      ; encoding: [0x71,0x0a,0xfa]
set1 PSW.0

# CHECK-INST: set1 0xffffa.1                      ; encoding: [0x71,0x1a,0xfa]
set1 PSW.1

# CHECK-INST: set1 0xffffa.2                      ; encoding: [0x71,0x2a,0xfa]
set1 PSW.2

# CHECK-INST: set1 0xffffa.3                      ; encoding: [0x71,0x3a,0xfa]
set1 PSW.3

# CHECK-INST: set1 0xffffa.4                      ; encoding: [0x71,0x4a,0xfa]
set1 PSW.4

# CHECK-INST: set1 0xffffa.5                      ; encoding: [0x71,0x5a,0xfa]
set1 PSW.5

# CHECK-INST: set1 0xffffa.6                      ; encoding: [0x71,0x6a,0xfa]
set1 PSW.6

# CHECK-INST: set1 0xffffa.7                      ; encoding: [0x71,0x7a,0xfa]
set1 PSW.7



# CHECK-INST: set1 [hl].0                         ; encoding: [0x71,0x82]
set1 [HL].0

# CHECK-INST: set1 [hl].1                         ; encoding: [0x71,0x92]
set1 [HL].1

# CHECK-INST: set1 [hl].2                         ; encoding: [0x71,0xa2]
set1 [HL].2

# CHECK-INST: set1 [hl].3                         ; encoding: [0x71,0xb2]
set1 [HL].3

# CHECK-INST: set1 [hl].4                         ; encoding: [0x71,0xc2]
set1 [HL].4

# CHECK-INST: set1 [hl].5                         ; encoding: [0x71,0xd2]
set1 [HL].5

# CHECK-INST: set1 [hl].6                         ; encoding: [0x71,0xe2]
set1 [HL].6

# CHECK-INST: set1 [hl].7                         ; encoding: [0x71,0xf2]
set1 [HL].7



# CHECK-INST: set1 es:!0x1111.0                         ; encoding: [0x11,0x71,0x00,A,A]
set1 ES:!0x1111.0

# CHECK-INST: set1 es:!0x1111.1                         ; encoding: [0x11,0x71,0x10,A,A]
set1 ES:!0x1111.1

# CHECK-INST: set1 es:!0x1111.2                         ; encoding: [0x11,0x71,0x20,A,A]
set1 ES:!0x1111.2

# CHECK-INST: set1 es:!0x1111.3                         ; encoding: [0x11,0x71,0x30,A,A]
set1 ES:!0x1111.3
 
# CHECK-INST: set1 es:!0x1111.4                         ; encoding: [0x11,0x71,0x40,A,A]
set1 ES:!0x1111.4

# CHECK-INST: set1 es:!0x1111.5                         ; encoding: [0x11,0x71,0x50,A,A]
set1 ES:!0x1111.5

# CHECK-INST: set1 es:!0x1111.6                         ; encoding: [0x11,0x71,0x60,A,A]
set1 ES:!0x1111.6

# CHECK-INST: set1 es:!0x1111.7                         ; encoding: [0x11,0x71,0x70,A,A]
set1 ES:!0x1111.7



# CHECK-INST: set1 es:[hl].0                      ; encoding: [0x11,0x71,0x82]
set1 ES:[HL].0

# CHECK-INST: set1 es:[hl].1                      ; encoding: [0x11,0x71,0x92]
set1 ES:[HL].1

# CHECK-INST: set1 es:[hl].2                      ; encoding: [0x11,0x71,0xa2]
set1 ES:[HL].2

# CHECK-INST: set1 es:[hl].3                      ; encoding: [0x11,0x71,0xb2]
set1 ES:[HL].3

# CHECK-INST: set1 es:[hl].4                      ; encoding: [0x11,0x71,0xc2]
set1 ES:[HL].4

# CHECK-INST: set1 es:[hl].5                      ; encoding: [0x11,0x71,0xd2]
set1 ES:[HL].5

# CHECK-INST: set1 es:[hl].6                      ; encoding: [0x11,0x71,0xe2]
set1 ES:[HL].6

# CHECK-INST: set1 es:[hl].7                      ; encoding: [0x11,0x71,0xf2]
set1 ES:[HL].7

# CHECK-INST: set1 cy                                 ; encoding: [0x71,0x80]
set1 CY
