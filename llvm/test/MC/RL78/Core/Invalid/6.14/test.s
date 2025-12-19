# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
skc AX

# CHECK-ERR: error: invalid operand for instruction
sknc AX

# CHECK-ERR: error: invalid operand for instruction
skz AX

# CHECK-ERR: error: invalid operand for instruction
sknz AX

# CHECK-ERR: error: invalid operand for instruction
skh AX

# CHECK-ERR: error: invalid operand for instruction
sknh AX
