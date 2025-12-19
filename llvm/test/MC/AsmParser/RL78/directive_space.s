# RUN: llvm-mc -triple rl78 %s | FileCheck %s

# CHECK: TEST0:
# CHECK: .skip 1
TEST0:  
        .skip 1

# CHECK: TEST1:
# CHECK: .skip	2,3
TEST1:  
        .skip 2, 3

# CHECK: TEST2:
# CHECK: .skip	1,3
TEST2:  
        .skip -(2 > 0), 3

# CHECK: TEST3:
# CHECK: .skip 1
TEST3:
        .skip 1

# CHECK: TEST4
# CHECK: .skip TEST0-TEST1
TEST4:
        .skip TEST0 - TEST1

# CHECK: TEST5
# CHECK: .skip -((TEST0-TEST1)>0)
TEST5:
        .skip -((TEST0 - TEST1) > 0)
