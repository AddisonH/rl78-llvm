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

# CHECK: .long 1310177520
.float 0x12f7.1ep+17
# CHECK: .long 1084227584
.float 0x.ap+3

# CHECK: .long 1094713344
.float 0x3p2
# CHECK: .long 872284160
.float 0x7fp-30
# CHECK: .long 3212836864
.float -0x1.0p0

# CHECK-ERROR: invalid hexadecimal floating-point constant: expected at least one exponent digit
.float 0xa.apa

# CHECK-ERROR: invalid hexadecimal floating-point constant: expected at least one exponent digit
.double -0x1.2p+

# CHECK-ERROR: invalid hexadecimal floating-point constant: expected at least one exponent digit
.double -0x1.2p

# CHECK-ERROR: invalid hexadecimal floating-point constant: expected at least one significand digit
.float 0xp2

# CHECK-ERROR: invalid hexadecimal floating-point constant: expected at least one significand digit
.float 0x.p5

# CHECK-ERROR: error: unexpected token in directive
.float 0x1.2

