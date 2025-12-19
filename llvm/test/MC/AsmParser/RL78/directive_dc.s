# RUN: not llvm-mc -triple rl78 %s | FileCheck %s
# RUN: not llvm-mc -triple rl78 %s 2>&1 > /dev/null| FileCheck %s --check-prefix=CHECK-ERROR

# CHECK: TEST0:
# CHECK: .byte 0
TEST0:
        .dc.b 0

# CHECK: TEST1:
# CHECK: .short 3
TEST1:
        .dc 3

# CHECK: TEST2:
# CHECK: .short 3
TEST2:
        .dc.w 3

# CHECK: TEST3:
# CHECK: .long 8
TEST3:
        .dc.l 8

# CHECK: TEST4:
# CHECK: .long 8
TEST4:
        .dc.a 8

# CHECK: TEST5
# CHECK: .long	1067412619
TEST5:
        .dc.s 1.2455

# CHECK-ERROR: error: .dc.x not currently supported for this target
TEST7:
        .dc.x 1.2e3
