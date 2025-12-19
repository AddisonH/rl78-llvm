# RUN: not llvm-mc -triple rl78 %s 2>&1 | FileCheck %s -check-prefix=ERROR

# CHECK: TEST0:
# CHECK: .lcomm a,7,4
# CHECK: .lcomm b,8
# CHECK: .lcomm c,0

# ELF doesn't like alignment on .lcomm.
# ERROR: alignment not supported on this target
TEST0:  
        .lcomm a, 8-1, 4
        .lcomm b,8
        .lcomm  c,  0
