# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: sel rb0                                 ; encoding: [0x61,0xcf]
sel RB0

# CHECK-INST: sel rb1                                 ; encoding: [0x61,0xdf]
sel RB1

# CHECK-INST: sel rb2                                 ; encoding: [0x61,0xef]
sel RB2

# CHECK-INST: sel rb3                                 ; encoding: [0x61,0xff]
sel RB3

# CHECK-INST: nop                                     ; encoding: [0x00]
nop

# CHECK-INST: ei                                      ; encoding: [0x71,0x7a,0xfa]
ei

# CHECK-INST: di                                      ; encoding: [0x71,0x7b,0xfa]
di

# CHECK-INST: halt                                    ; encoding: [0x61,0xed]
halt

# CHECK-INST: stop                                    ; encoding: [0x61,0xfd]
stop
