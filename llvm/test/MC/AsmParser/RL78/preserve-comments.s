	;RUN: llvm-mc -preserve-comments -n -triple rl78 < %s > %t
	;RUN: diff -b %s %t
	;RUN: llvm-mc -preserve-comments -n -triple rl78 < %p/Inputs/no-newline-at-end-of-file.s | FileCheck %s
	.text

foo:	;Comment here
	;comment here
	nop
	;if DIRECTIVE COMMENT
	;# WHOLE LINE COMMENT
	nop	;# EOL COMMENT
	;endif
	.ident	"clang version 3.9.0"
	.section	".note.GNU-stack","",@progbits

	;Confirm we don't crash on inputs without a terminating newline.
	;CHECK: .text
