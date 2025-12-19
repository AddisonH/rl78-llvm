# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
push a

# CHECK-ERR: error: invalid operand for instruction
pop a

# CHECK-ERR: error: invalid operand for instruction
movw ax, ax

# CHECK-ERR: error: invalid operand for instruction
addw sp, ax

# CHECK-ERR: error: invalid operand for instruction
subw sp, ax
