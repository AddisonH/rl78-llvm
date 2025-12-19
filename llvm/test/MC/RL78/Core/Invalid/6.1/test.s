# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: invalid operand for instruction
clrb ax

# CHECK-ERR: error: invalid operand for instruction
mov #0x1212

# CHECK-ERR: error: invalid operand for instruction
movs #0x1212

# CHECK-ERR: error: invalid operand for instruction
oneb ax

# CHECK-ERR: error: invalid operand for instruction
xch ax, ax
