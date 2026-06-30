# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: clrb a                                  ; encoding: [0xf1]
clrb A

# CHECK-INST: clrb x                                  ; encoding: [0xf0]
clrb X

# CHECK-INST: clrb b                                  ; encoding: [0xf3]
clrb B

# CHECK-INST: clrb c                                  ; encoding: [0xf2]
clrb C

# CHECK-INST: clrb 0xffe20                         ; encoding: [0xf4,0x20]
clrb 0xFFE20

# CHECK-INST: clrb !0xf2200                           ; encoding: [0xf5,0x00,0x22]
clrb !0x2200

# CHECK-INST: clrb es:!0x2200                         ; encoding: [0x11,0xf5,0x00,0x22]
clrb ES:!0x2200
