# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
sel rb4

# CHECK-ERR: error: invalid operand for instruction
nop AX

# CHECK-ERR: error: invalid operand for instruction
ei AX

# CHECK-ERR: error: invalid operand for instruction
di AX

# CHECK-ERR: error: invalid operand for instruction
halt AX

# CHECK-ERR: error: invalid operand for instruction
stop AX
