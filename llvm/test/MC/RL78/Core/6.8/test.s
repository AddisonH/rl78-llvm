# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: ror a, 1                                ; encoding: [0x61,0xdb]
ror A, 1


# CHECK-INST: rol a, 1                                ; encoding: [0x61,0xeb]
rol A, 1


# CHECK-INST: rorc a, 1                               ; encoding: [0x61,0xfb]
rorc A, 1

# CHECK-INST: rolc a, 1                               ; encoding: [0x61,0xdc]
rolc A, 1


# CHECK-INST: rolwc ax, 1                             ; encoding: [0x61,0xee]
rolwc AX, 1

# CHECK-INST: rolwc bc, 1                             ; encoding: [0x61,0xfe]
rolwc BC, 1
