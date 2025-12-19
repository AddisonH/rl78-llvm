# RUN: llvm-mc -triple=rl78 %s | FileCheck %s

# CHECK: movw ax, #15
movw ax, #3 ! ~12
