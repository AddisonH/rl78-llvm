# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
shr A, 8


# CHECK-ERR: error: invalid operand for instruction
shrw AX, 16


# CHECK-ERR: error: invalid operand for instruction
shl A, 8

# CHECK-ERR: error: invalid operand for instruction
shl B, 8

# CHECK-ERR: error: invalid operand for instruction
shl C, 8


# CHECK-ERR: error: invalid operand for instruction
shlw AX, 16

# CHECK-ERR: error: invalid operand for instruction
shlw BC, 16


# CHECK-ERR: error: invalid operand for instruction
sar A, 8

# CHECK-ERR: error: invalid operand for instruction
sarw AX, 16
