; The instructions the cores differ in: SEL RBn needs register banks (S2 and
; S3), the multiply/divide/multiply-accumulate instructions the S3 core.
; RUN: llvm-mc -triple=rl78 -mcpu=RL78_S3 -show-encoding %s | FileCheck %s
; RUN: not llvm-mc -triple=rl78 -mcpu=RL78_S2 -show-encoding %s 2>&1 \
; RUN:   | FileCheck %s --check-prefix=S2
; RUN: not llvm-mc -triple=rl78 -mcpu=RL78_S1 -show-encoding %s 2>&1 \
; RUN:   | FileCheck %s --check-prefixes=S1,S2

; CHECK: sel rb1 ; encoding: [0x61,0xdf]
; S1: :[[@LINE+2]]:1: error: instruction requires: the S2 or S3 core
; S2-NOT: :[[@LINE+1]]:1: error
sel rb1

; CHECK: mulhu ; encoding: [0xce,0xfb,0x01]
; S2: :[[@LINE+1]]:1: error: instruction requires: the S3 core
mulhu
; CHECK: mulh ; encoding: [0xce,0xfb,0x02]
; S2: :[[@LINE+1]]:1: error: instruction requires: the S3 core
mulh
; CHECK: divhu ; encoding: [0xce,0xfb,0x03]
; S2: :[[@LINE+1]]:1: error: instruction requires: the S3 core
divhu
; CHECK: divwu ; encoding: [0xce,0xfb,0x0b]
; S2: :[[@LINE+1]]:1: error: instruction requires: the S3 core
divwu
; CHECK: machu ; encoding: [0xce,0xfb,0x05]
; S2: :[[@LINE+1]]:1: error: instruction requires: the S3 core
machu
; CHECK: mach ; encoding: [0xce,0xfb,0x06]
; S2: :[[@LINE+1]]:1: error: instruction requires: the S3 core
mach

; Every core has MULU.
; CHECK: mulu x ; encoding: [0xd6]
; S2: mulu x ; encoding: [0xd6]
mulu x
