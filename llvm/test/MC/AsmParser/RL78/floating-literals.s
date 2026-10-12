# RUN: not llvm-mc -triple rl78 %s 2> /dev/null | FileCheck %s
# RUN: not llvm-mc -triple rl78 %s 2>&1 > /dev/null| FileCheck %s --check-prefix=CHECK-ERROR

# CHECK: .long	1067412619
# CHECK: .long	1075000115
# CHECK: .long	1077936128
# CHECK: .long	1082549862
.single 1.2455, +2.3, 3, + 4.2

# CHECK: .long	2139095040
.single InFinIty


# CHECK: .long	4286578688
.single -iNf


# CHECK: .long	2147483647
.single nAN


# CHECK: .long  1067928519
.float 1.307



# CHECK-ERROR: :[[#@LINE+1]]:12: error: unexpected token
.double 1e1e
# CHECK-ERROR: :[[#@LINE+1]]:9: error: invalid sign in float literal
.double 2.+1

# RL78 has no hexadecimal floating-point literals: a dot after a hexadecimal
# number starts a bit position ("set1 0xfff00.2").
# CHECK-ERROR: :[[#@LINE+1]]:8: error: invalid floating point literal
.float 0x3.8p1
