# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: or1 cy, 0xffe20.0                   ; encoding: [0x71,0x06,0x20]
or1 CY, 0xFFE20.0

# CHECK-INST: or1 cy, 0xffe20.1                   ; encoding: [0x71,0x16,0x20]
or1 CY, 0xFFE20.1

# CHECK-INST: or1 cy, 0xffe20.2                   ; encoding: [0x71,0x26,0x20]
or1 CY, 0xFFE20.2

# CHECK-INST: or1 cy, 0xffe20.3                   ; encoding: [0x71,0x36,0x20]
or1 CY, 0xFFE20.3

# CHECK-INST: or1 cy, 0xffe20.4                   ; encoding: [0x71,0x46,0x20]
or1 CY, 0xFFE20.4

# CHECK-INST: or1 cy, 0xffe20.5                   ; encoding: [0x71,0x56,0x20]
or1 CY, 0xFFE20.5

# CHECK-INST: or1 cy, 0xffe20.6                   ; encoding: [0x71,0x66,0x20]
or1 CY, 0xFFE20.6

# CHECK-INST: or1 cy, 0xffe20.7                   ; encoding: [0x71,0x76,0x20]
or1 CY, 0xFFE20.7



# CHECK-INST: or1 cy, saddr+0.0                      ; encoding: [0x71,0x06,A]
or1 CY, saddr.0

# CHECK-INST: or1 cy, saddr+0.1                      ; encoding: [0x71,0x16,A]
or1 CY, saddr.1

# CHECK-INST: or1 cy, saddr+0.2                      ; encoding: [0x71,0x26,A]
or1 CY, saddr.2

# CHECK-INST: or1 cy, saddr+0.3                      ; encoding: [0x71,0x36,A]
or1 CY, saddr.3

# CHECK-INST: or1 cy, saddr+0.4                      ; encoding: [0x71,0x46,A]
or1 CY, saddr.4

# CHECK-INST: or1 cy, saddr+0.5                      ; encoding: [0x71,0x56,A]
or1 CY, saddr.5

# CHECK-INST: or1 cy, saddr+0.6                      ; encoding: [0x71,0x66,A]
or1 CY, saddr.6

# CHECK-INST: or1 cy, saddr+0.7                      ; encoding: [0x71,0x76,A]
or1 CY, saddr.7



# CHECK-INST: or1 cy, 0xfff20.0                      ; encoding: [0x71,0x0e,0x20]
or1 CY, 0xFFF20.0

# CHECK-INST: or1 cy, 0xfff20.1                      ; encoding: [0x71,0x1e,0x20]
or1 CY, 0xFFF20.1

# CHECK-INST: or1 cy, 0xfff20.2                      ; encoding: [0x71,0x2e,0x20]
or1 CY, 0xFFF20.2

# CHECK-INST: or1 cy, 0xfff20.3                      ; encoding: [0x71,0x3e,0x20]
or1 CY, 0xFFF20.3

# CHECK-INST: or1 cy, 0xfff20.4                      ; encoding: [0x71,0x4e,0x20]
or1 CY, 0xFFF20.4

# CHECK-INST: or1 cy, 0xfff20.5                      ; encoding: [0x71,0x5e,0x20]
or1 CY, 0xFFF20.5

# CHECK-INST: or1 cy, 0xfff20.6                      ; encoding: [0x71,0x6e,0x20]
or1 CY, 0xFFF20.6

# CHECK-INST: or1 cy, 0xfff20.7                      ; encoding: [0x71,0x7e,0x20]
or1 CY, 0xFFF20.7



# CHECK-INST: or1 cy, a.0                            ; encoding: [0x71,0x8e]
or1 CY, A.0

# CHECK-INST: or1 cy, a.1                            ; encoding: [0x71,0x9e]
or1 CY, A.1

# CHECK-INST: or1 cy, a.2                            ; encoding: [0x71,0xae]
or1 CY, A.2

# CHECK-INST: or1 cy, a.3                            ; encoding: [0x71,0xbe]
or1 CY, A.3

# CHECK-INST: or1 cy, a.4                            ; encoding: [0x71,0xce]
or1 CY, A.4

# CHECK-INST: or1 cy, a.5                            ; encoding: [0x71,0xde]
or1 CY, A.5

# CHECK-INST: or1 cy, a.6                            ; encoding: [0x71,0xee]
or1 CY, A.6

# CHECK-INST: or1 cy, a.7                            ; encoding: [0x71,0xfe]
or1 CY, A.7



# CHECK-INST: or1 cy, 0xffffa.0                      ; encoding: [0x71,0x0e,0xfa]
or1 CY, PSW.0

# CHECK-INST: or1 cy, 0xffffa.1                      ; encoding: [0x71,0x1e,0xfa]
or1 CY, PSW.1

# CHECK-INST: or1 cy, 0xffffa.2                      ; encoding: [0x71,0x2e,0xfa]
or1 CY, PSW.2

# CHECK-INST: or1 cy, 0xffffa.3                      ; encoding: [0x71,0x3e,0xfa]
or1 CY, PSW.3

# CHECK-INST: or1 cy, 0xffffa.4                      ; encoding: [0x71,0x4e,0xfa]
or1 CY, PSW.4

# CHECK-INST: or1 cy, 0xffffa.5                      ; encoding: [0x71,0x5e,0xfa]
or1 CY, PSW.5

# CHECK-INST: or1 cy, 0xffffa.6                      ; encoding: [0x71,0x6e,0xfa]
or1 CY, PSW.6

# CHECK-INST: or1 cy, 0xffffa.7                      ; encoding: [0x71,0x7e,0xfa]
or1 CY, PSW.7



# CHECK-INST: or1 cy, [hl].0                         ; encoding: [0x71,0x86]
or1 CY, [HL].0

# CHECK-INST: or1 cy, [hl].1                         ; encoding: [0x71,0x96]
or1 CY, [HL].1

# CHECK-INST: or1 cy, [hl].2                         ; encoding: [0x71,0xa6]
or1 CY, [HL].2

# CHECK-INST: or1 cy, [hl].3                         ; encoding: [0x71,0xb6]
or1 CY, [HL].3

# CHECK-INST: or1 cy, [hl].4                         ; encoding: [0x71,0xc6]
or1 CY, [HL].4

# CHECK-INST: or1 cy, [hl].5                         ; encoding: [0x71,0xd6]
or1 CY, [HL].5

# CHECK-INST: or1 cy, [hl].6                         ; encoding: [0x71,0xe6]
or1 CY, [HL].6

# CHECK-INST: or1 cy, [hl].7                         ; encoding: [0x71,0xf6]
or1 CY, [HL].7



# CHECK-INST: or1 cy, es:[hl].0                      ; encoding: [0x11,0x71,0x86]
or1 CY, ES:[HL].0

# CHECK-INST: or1 cy, es:[hl].1                      ; encoding: [0x11,0x71,0x96]
or1 CY, ES:[HL].1

# CHECK-INST: or1 cy, es:[hl].2                      ; encoding: [0x11,0x71,0xa6]
or1 CY, ES:[HL].2

# CHECK-INST: or1 cy, es:[hl].3                      ; encoding: [0x11,0x71,0xb6]
or1 CY, ES:[HL].3

# CHECK-INST: or1 cy, es:[hl].4                      ; encoding: [0x11,0x71,0xc6]
or1 CY, ES:[HL].4

# CHECK-INST: or1 cy, es:[hl].5                      ; encoding: [0x11,0x71,0xd6]
or1 CY, ES:[HL].5

# CHECK-INST: or1 cy, es:[hl].6                      ; encoding: [0x11,0x71,0xe6]
or1 CY, ES:[HL].6

# CHECK-INST: or1 cy, es:[hl].7                      ; encoding: [0x11,0x71,0xf6]
or1 CY, ES:[HL].7
