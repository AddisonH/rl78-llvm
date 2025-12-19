# RUN: not llvm-mc %s -triple=rl78 2>&1 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-ERR %s

# CHECK-ERR: error: Instruction using illegal operand
br !0xf1000
