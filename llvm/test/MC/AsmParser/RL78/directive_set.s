# RUN: llvm-mc -triple rl78 %s | FileCheck %s

# CHECK: TEST0:
# CHECK: .set a, 0
# CHECK-NOT: .no_dead_strip a
TEST0:  
        .set a, 0
        
# CHECK: TEST1:
# CHECK: .set a, 0
# CHECK-NOT: .no_dead_strip a
TEST1:  
        .equ a, 0

