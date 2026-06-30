# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: onew ax                                 ; encoding: [0xe6]
onew ax

# CHECK-INST: onew bc                                 ; encoding: [0xe7]
onew bc
