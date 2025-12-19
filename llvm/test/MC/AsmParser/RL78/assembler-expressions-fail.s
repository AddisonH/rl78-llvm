# RUN: not llvm-mc -triple rl78 %s 2>&1 | FileCheck %s --check-prefix=ERR
# RUN: not llvm-mc -filetype=obj -triple rl78 %s 2>&1 | FileCheck %s --check-prefix=ERR
	
.text

test2:	
	br baz
# ERR: [[@LINE+1]]:5: error: expected absolute expression
.if . - text2 == 1
	nop
.else
	ret
.endif
	push ax

# No additional errors.
#	
# 	ERR-NOT: {{[0-9]+}}:{{[0-9]+}}: error:	
