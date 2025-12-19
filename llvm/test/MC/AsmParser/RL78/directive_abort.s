# RUN: not llvm-mc -triple rl78 %s 2> %t
# RUN: FileCheck -input-file %t %s

# CHECK: error: .abort 'please stop assembing'
TEST0:
	.abort       please stop assembing
