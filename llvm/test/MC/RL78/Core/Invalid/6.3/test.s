# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s


# CHECK-ERR: error: invalid operand for instruction
add A, AX

# CHECK-ERR: error: invalid operand for instruction
addc A, AX

# CHECK-ERR: error: invalid operand for instruction
sub A, AX

# CHECK-ERR: error: invalid operand for instruction
subc A, AX

# CHECK-ERR: error: invalid operand for instruction
and a,ax

# CHECK-ERR: error: invalid operand for instruction
or ax, ax

# CHECK-ERR: error: invalid operand for instruction
xor ax, ax

# CHECK-ERR: error: invalid operand for instruction
cmp ax, ax

# CHECK-ERR: error: invalid operand for instruction
cmp0 de

# CHECK-ERR: error: invalid operand for instruction
cmps de
