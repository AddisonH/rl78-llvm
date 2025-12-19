# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
MULU AX

# CHECK-ERR: error: invalid operand for instruction
MULHU AX

# CHECK-ERR: error: invalid operand for instruction
MULH AX

# CHECK-ERR: error: invalid operand for instruction
DIVHU AX

# CHECK-ERR: error: invalid operand for instruction
DIVWU AX

# CHECK-ERR: error: invalid operand for instruction
MACHU AX

# CHECK-ERR: error: invalid operand for instruction
MACH AX
