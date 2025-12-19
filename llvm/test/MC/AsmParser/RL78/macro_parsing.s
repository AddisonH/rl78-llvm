# RUN: llvm-mc -triple rl78 %s | FileCheck %s

        .macro DEF num
        mov a, #0x\num
        .endm
        DEF 02
        DEF 08
        DEF 09
        DEF 0A
        DEF 10

# CHECK: mov a, #2
# CHECK: mov a, #8
# CHECK: mov a, #9
# CHECK: mov a, #10
# CHECK: mov a, #16
