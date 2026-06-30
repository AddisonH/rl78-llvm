# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: mulu x                                  ; encoding: [0xd6]
mulu X

# CHECK-INST: mulhu                                   ; encoding: [0xce,0xfb,0x01]
mulhu

# CHECK-INST: mulh                                    ; encoding: [0xce,0xfb,0x02]
mulh

# CHECK-INST: divhu                                   ; encoding: [0xce,0xfb,0x03]
divhu

# CHECK-INST: divwu                                   ; encoding: [0xce,0xfb,0x0b]
divwu

# CHECK-INST: machu                                   ; encoding: [0xce,0xfb,0x05]
machu

# CHECK-INST: mach                                    ; encoding: [0xce,0xfb,0x06]
mach
