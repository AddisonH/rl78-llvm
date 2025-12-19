# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
call [ax]

# CHECK-ERR: error: invalid operand for instruction
brk ax

# CHECK-ERR: error: invalid operand for instruction
ret ax

# CHECK-ERR: error: invalid operand for instruction
reti ax

# CHECK-ERR: error: invalid operand for instruction
retb ax

# CHECK-ERR: error: Instruction using illegal operand
callt [0x128]
