# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: and1 cy, 0xffe20.0                   ; encoding: [0x71,0x05,0x20]
and1 CY, 0xFFE20.0

# CHECK-INST: and1 cy, 0xffe20.1                   ; encoding: [0x71,0x15,0x20]
and1 CY, 0xFFE20.1

# CHECK-INST: and1 cy, 0xffe20.2                   ; encoding: [0x71,0x25,0x20]
and1 CY, 0xFFE20.2

# CHECK-INST: and1 cy, 0xffe20.3                   ; encoding: [0x71,0x35,0x20]
and1 CY, 0xFFE20.3

# CHECK-INST: and1 cy, 0xffe20.4                   ; encoding: [0x71,0x45,0x20]
and1 CY, 0xFFE20.4

# CHECK-INST: and1 cy, 0xffe20.5                   ; encoding: [0x71,0x55,0x20]
and1 CY, 0xFFE20.5

# CHECK-INST: and1 cy, 0xffe20.6                   ; encoding: [0x71,0x65,0x20]
and1 CY, 0xFFE20.6

# CHECK-INST: and1 cy, 0xffe20.7                   ; encoding: [0x71,0x75,0x20]
and1 CY, 0xFFE20.7



# CHECK-INST: and1 cy, saddr+0.0                      ; encoding: [0x71,0x05,A]
and1 CY, saddr.0

# CHECK-INST: and1 cy, saddr+0.1                      ; encoding: [0x71,0x15,A]
and1 CY, saddr.1

# CHECK-INST: and1 cy, saddr+0.2                      ; encoding: [0x71,0x25,A]
and1 CY, saddr.2

# CHECK-INST: and1 cy, saddr+0.3                      ; encoding: [0x71,0x35,A]
and1 CY, saddr.3

# CHECK-INST: and1 cy, saddr+0.4                      ; encoding: [0x71,0x45,A]
and1 CY, saddr.4

# CHECK-INST: and1 cy, saddr+0.5                      ; encoding: [0x71,0x55,A]
and1 CY, saddr.5

# CHECK-INST: and1 cy, saddr+0.6                      ; encoding: [0x71,0x65,A]
and1 CY, saddr.6

# CHECK-INST: and1 cy, saddr+0.7                      ; encoding: [0x71,0x75,A]
and1 CY, saddr.7



# CHECK-INST: and1 cy, 0xfff20.0                      ; encoding: [0x71,0x0d,0x20]
and1 CY, 0xFFF20.0

# CHECK-INST: and1 cy, 0xfff20.1                      ; encoding: [0x71,0x1d,0x20]
and1 CY, 0xFFF20.1

# CHECK-INST: and1 cy, 0xfff20.2                      ; encoding: [0x71,0x2d,0x20]
and1 CY, 0xFFF20.2

# CHECK-INST: and1 cy, 0xfff20.3                      ; encoding: [0x71,0x3d,0x20]
and1 CY, 0xFFF20.3

# CHECK-INST: and1 cy, 0xfff20.4                      ; encoding: [0x71,0x4d,0x20]
and1 CY, 0xFFF20.4

# CHECK-INST: and1 cy, 0xfff20.5                      ; encoding: [0x71,0x5d,0x20]
and1 CY, 0xFFF20.5

# CHECK-INST: and1 cy, 0xfff20.6                      ; encoding: [0x71,0x6d,0x20]
and1 CY, 0xFFF20.6

# CHECK-INST: and1 cy, 0xfff20.7                      ; encoding: [0x71,0x7d,0x20]
and1 CY, 0xFFF20.7



# CHECK-INST: and1 cy, a.0                            ; encoding: [0x71,0x8d]
and1 CY, A.0

# CHECK-INST: and1 cy, a.1                            ; encoding: [0x71,0x9d]
and1 CY, A.1

# CHECK-INST: and1 cy, a.2                            ; encoding: [0x71,0xad]
and1 CY, A.2

# CHECK-INST: and1 cy, a.3                            ; encoding: [0x71,0xbd]
and1 CY, A.3

# CHECK-INST: and1 cy, a.4                            ; encoding: [0x71,0xcd]
and1 CY, A.4

# CHECK-INST: and1 cy, a.5                            ; encoding: [0x71,0xdd]
and1 CY, A.5

# CHECK-INST: and1 cy, a.6                            ; encoding: [0x71,0xed]
and1 CY, A.6

# CHECK-INST: and1 cy, a.7                            ; encoding: [0x71,0xfd]
and1 CY, A.7



# CHECK-INST: and1 cy, 0xffffa.0                      ; encoding: [0x71,0x0d,0xfa]
and1 CY, PSW.0

# CHECK-INST: and1 cy, 0xffffa.1                      ; encoding: [0x71,0x1d,0xfa]
and1 CY, PSW.1

# CHECK-INST: and1 cy, 0xffffa.2                      ; encoding: [0x71,0x2d,0xfa]
and1 CY, PSW.2

# CHECK-INST: and1 cy, 0xffffa.3                      ; encoding: [0x71,0x3d,0xfa]
and1 CY, PSW.3

# CHECK-INST: and1 cy, 0xffffa.4                      ; encoding: [0x71,0x4d,0xfa]
and1 CY, PSW.4

# CHECK-INST: and1 cy, 0xffffa.5                      ; encoding: [0x71,0x5d,0xfa]
and1 CY, PSW.5

# CHECK-INST: and1 cy, 0xffffa.6                      ; encoding: [0x71,0x6d,0xfa]
and1 CY, PSW.6

# CHECK-INST: and1 cy, 0xffffa.7                      ; encoding: [0x71,0x7d,0xfa]
and1 CY, PSW.7



# CHECK-INST: and1 cy, [hl].0                         ; encoding: [0x71,0x85]
and1 CY, [HL].0

# CHECK-INST: and1 cy, [hl].1                         ; encoding: [0x71,0x95]
and1 CY, [HL].1

# CHECK-INST: and1 cy, [hl].2                         ; encoding: [0x71,0xa5]
and1 CY, [HL].2

# CHECK-INST: and1 cy, [hl].3                         ; encoding: [0x71,0xb5]
and1 CY, [HL].3

# CHECK-INST: and1 cy, [hl].4                         ; encoding: [0x71,0xc5]
and1 CY, [HL].4

# CHECK-INST: and1 cy, [hl].5                         ; encoding: [0x71,0xd5]
and1 CY, [HL].5

# CHECK-INST: and1 cy, [hl].6                         ; encoding: [0x71,0xe5]
and1 CY, [HL].6

# CHECK-INST: and1 cy, [hl].7                         ; encoding: [0x71,0xf5]
and1 CY, [HL].7



# CHECK-INST: and1 cy, es:[hl].0                      ; encoding: [0x11,0x71,0x85]
and1 CY, ES:[HL].0

# CHECK-INST: and1 cy, es:[hl].1                      ; encoding: [0x11,0x71,0x95]
and1 CY, ES:[HL].1

# CHECK-INST: and1 cy, es:[hl].2                      ; encoding: [0x11,0x71,0xa5]
and1 CY, ES:[HL].2

# CHECK-INST: and1 cy, es:[hl].3                      ; encoding: [0x11,0x71,0xb5]
and1 CY, ES:[HL].3

# CHECK-INST: and1 cy, es:[hl].4                      ; encoding: [0x11,0x71,0xc5]
and1 CY, ES:[HL].4

# CHECK-INST: and1 cy, es:[hl].5                      ; encoding: [0x11,0x71,0xd5]
and1 CY, ES:[HL].5

# CHECK-INST: and1 cy, es:[hl].6                      ; encoding: [0x11,0x71,0xe5]
and1 CY, ES:[HL].6

# CHECK-INST: and1 cy, es:[hl].7                      ; encoding: [0x11,0x71,0xf5]
and1 CY, ES:[HL].7
