# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
inc ax

# CHECK-ERR: error: invalid operand for instruction
dec ax

# CHECK-ERR: error: invalid operand for instruction
incw #0xf2000

# CHECK-ERR: error: invalid operand for instruction
decw #0xf2000
