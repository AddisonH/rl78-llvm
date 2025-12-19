# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
bc AX

# CHECK-ERR: error: invalid operand for instruction
bnc AX

# CHECK-ERR: error: invalid operand for instruction
bz AX

# CHECK-ERR: error: invalid operand for instruction
bnz AX

# CHECK-ERR: error: invalid operand for instruction
bh AX

# CHECK-ERR: error: invalid operand for instruction
bnh AX

# CHECK-ERR: error: invalid operand for instruction
bt 0xFFE20.5, AX

# CHECK-ERR: error: invalid operand for instruction
bt sfr.5, AX

# CHECK-ERR: error: invalid operand for instruction
bt A.5, AX

# CHECK-ERR: error: invalid operand for instruction
bt PSW.5, AX

# CHECK-ERR: error: invalid operand for instruction
bt [HL].5, AX

# CHECK-ERR: error: invalid operand for instruction
bt es:[hl].5, AX


# CHECK-ERR: error: invalid operand for instruction
bf sfr.5, AX

# CHECK-ERR: error: invalid operand for instruction
bf A.5, AX

# CHECK-ERR: error: invalid operand for instruction
bf PSW.5, AX

# CHECK-ERR: error: invalid operand for instruction
bf [HL].5, AX

# CHECK-ERR: error: invalid operand for instruction
bf es:[hl].5, AX


# CHECK-ERR: error: invalid operand for instruction
btclr sfr.5, AX

# CHECK-ERR: error: invalid operand for instruction
btclr A.5, AX

# CHECK-ERR: error: invalid operand for instruction
btclr PSW.5, AX

# CHECK-ERR: error: invalid operand for instruction
btclr [HL].5, AX

# CHECK-ERR: error: invalid operand for instruction
btclr es:[hl].5, AX
