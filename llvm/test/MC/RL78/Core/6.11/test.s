# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: push PSW                                ; encoding: [0x61,0xdd]
push PSW

# CHECK-INST: push ax                                 ; encoding: [0xc1]
push AX

# CHECK-INST: push bc                                 ; encoding: [0xc3]
push BC

# CHECK-INST: push de                                 ; encoding: [0xc5]
push DE

# CHECK-INST: push hl                                 ; encoding: [0xc7]
push HL


# CHECK-INST: pop PSW                                 ; encoding: [0x61,0xcd]
pop psw

# CHECK-INST: pop ax                                  ; encoding: [0xc0]
pop AX

# CHECK-INST: pop bc                                  ; encoding: [0xc2]
pop BC

# CHECK-INST: pop de                                  ; encoding: [0xc4]
pop DE

# CHECK-INST: pop hl                                  ; encoding: [0xc6]
pop HL


# CHECK-INST: movw sp, #1212                          ; encoding: [0xcb,0xf8,0xbc,0x04]
movw sp, #1212

# CHECK-INST: movw sp, ax                             ; encoding: [0xbe,0xf8]
movw sp, AX


# CHECK-INST: movw ax, sp                             ; encoding: [0xae,0xf8]
movw AX, sp

# CHECK-INST: movw hl, sp                             ; encoding: [0xfb,0xf8,0xff]
movw HL, sp

# CHECK-INST: movw bc, sp                             ; encoding: [0xdb,0xf8,0xff]
movw BC, sp

# CHECK-INST: movw de, sp                             ; encoding: [0xeb,0xf8,0xff]
movw DE, sp


# CHECK-INST: addw sp, #12                            ; encoding: [0x10,0x0c]
addw sp, #12

# CHECK-INST: subw sp, #12                            ; encoding: [0x20,0x0c]
subw sp, #12
