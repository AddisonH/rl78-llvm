# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
clrw de

# CHECK-ERR: error: invalid operand for instruction
movw ax, ax

# CHECK-ERR: error: invalid operand for instruction
onew de

# CHECK-ERR: error: invalid operand for instruction
xchw ax, #12
