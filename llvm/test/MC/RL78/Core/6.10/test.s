# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: call ax                                 ; encoding: [0x61,0xca]
call AX

# CHECK-INST: call bc                                 ; encoding: [0x61,0xda]
call BC

# CHECK-INST: call de                                 ; encoding: [0x61,0xea]
call DE

# CHECK-INST: call hl                                 ; encoding: [0x61,0xfa]
call HL


# CHECK-INST: call $!0x2000                           ; encoding: [0xfe,0x00,0x20]
call $!0x2000

# CHECK-INST: call !0x2000                            ; encoding: [0xfd,0x00,0x20]
call !0x2000

# CHECK-INST: call !!0xf2000                          ; encoding: [0xfc,0x00,0x20,0x0f]
call !!0xf2000


# CHECK-INST: callt [0x0080]                          ; encoding: [0x61,0x84]
callt [0x00080]

# CHECK-INST: callt [0x0082]                          ; encoding: [0x61,0x94]
callt [0x00082]

# CHECK-INST: callt [0x0084]                          ; encoding: [0x61,0xa4]
callt [0x00084]

# CHECK-INST: callt [0x0086]                          ; encoding: [0x61,0xb4]
callt [0x00086]

# CHECK-INST: callt [0x0088]                          ; encoding: [0x61,0xc4]
callt [0x00088]

# CHECK-INST: callt [0x008a]                          ; encoding: [0x61,0xd4]
callt [0x0008A]

# CHECK-INST: callt [0x008c]                          ; encoding: [0x61,0xe4]
callt [0x0008C]

# CHECK-INST: callt [0x008e]                          ; encoding: [0x61,0xf4]
callt [0x0008E]

# CHECK-INST: callt [0x0090]                          ; encoding: [0x61,0x85]
callt [0x00090]

# CHECK-INST: callt [0x0092]                          ; encoding: [0x61,0x95]
callt [0x00092]

# CHECK-INST: callt [0x0094]                          ; encoding: [0x61,0xa5]
callt [0x00094]

# CHECK-INST: callt [0x0096]                          ; encoding: [0x61,0xb5]
callt [0x00096]

# CHECK-INST: callt [0x0098]                          ; encoding: [0x61,0xc5]
callt [0x00098]

# CHECK-INST: callt [0x009a]                          ; encoding: [0x61,0xd5]
callt [0x0009A]

# CHECK-INST: callt [0x009c]                          ; encoding: [0x61,0xe5]
callt [0x0009C]

# CHECK-INST: callt [0x009e]                          ; encoding: [0x61,0xf5]
callt [0x0009E]

# CHECK-INST: callt [0x00a0]                          ; encoding: [0x61,0x86]
callt [0x000A0]

# CHECK-INST: callt [0x00a2]                          ; encoding: [0x61,0x96]
callt [0x000A2]

# CHECK-INST: callt [0x00a4]                          ; encoding: [0x61,0xa6]
callt [0x000A4]

# CHECK-INST: callt [0x00a6]                          ; encoding: [0x61,0xb6]
callt [0x000A6]

# CHECK-INST: callt [0x00a8]                          ; encoding: [0x61,0xc6]
callt [0x000A8]

# CHECK-INST: callt [0x00aa]                          ; encoding: [0x61,0xd6]
callt [0x000AA]

# CHECK-INST: callt [0x00ac]                          ; encoding: [0x61,0xe6]
callt [0x000AC]

# CHECK-INST: callt [0x00ae]                          ; encoding: [0x61,0xf6]
callt [0x000AE]

# CHECK-INST: callt [0x00b0]                          ; encoding: [0x61,0x87]
callt [0x000B0]

# CHECK-INST: callt [0x00b2]                          ; encoding: [0x61,0x97]
callt [0x000B2]

# CHECK-INST: callt [0x00b4]                          ; encoding: [0x61,0xa7]
callt [0x000B4]

# CHECK-INST: callt [0x00b6]                          ; encoding: [0x61,0xb7]
callt [0x000B6]

# CHECK-INST: callt [0x00b8]                          ; encoding: [0x61,0xc7]
callt [0x000B8]

# CHECK-INST: callt [0x00ba]                          ; encoding: [0x61,0xd7]
callt [0x000BA]

# CHECK-INST: callt [0x00bc]                          ; encoding: [0x61,0xe7]
callt [0x000BC]

# CHECK-INST: callt [0x00be]                          ; encoding: [0x61,0xf7]
callt [0x000BE]


# CHECK-INST: brk                                     ; encoding: [0x61,0xcc]
brk

# CHECK-INST: ret                                     ; encoding: [0xd7]
ret

# CHECK-INST: reti                                    ; encoding: [0x61,0xfc]
reti

# CHECK-INST: retb                                    ; encoding: [0x61,0xec]
retb
