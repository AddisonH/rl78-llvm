# RUN: llvm-mc -triple rl78 %s | FileCheck %s

# CHECK: TEST0:
# CHECK: .globl a
# CHECK: .globl b
TEST0:  
        .globl a, b
