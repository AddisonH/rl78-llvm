# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
ror A, 2


# CHECK-ERR: error: invalid operand for instruction
rol A, 2


# CHECK-ERR: error: invalid operand for instruction
rorc A, 2

# CHECK-ERR: error: invalid operand for instruction
rolc A, 2


# CHECK-ERR: error: invalid operand for instruction
rolwc AX, 2

# CHECK-ERR: error: invalid operand for instruction
rolwc BC, 2
