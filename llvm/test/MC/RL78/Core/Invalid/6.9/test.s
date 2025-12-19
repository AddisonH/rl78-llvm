# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
and1 CY, BC

# CHECK-ERR: error: invalid operand for instruction
clr1 BC

# CHECK-ERR: error: invalid operand for instruction
not1 BC

# CHECK-ERR: error: invalid operand for instruction
set1 BC

# CHECK-ERR: error: invalid operand for instruction
xor1 BC

# CHECK-ERR: error: invalid operand for instruction
or1 BC

# CHECK-ERR: error: invalid operand for instruction
and1 BC

# CHECK-ERR: error: invalid operand for instruction
mov1 BC
