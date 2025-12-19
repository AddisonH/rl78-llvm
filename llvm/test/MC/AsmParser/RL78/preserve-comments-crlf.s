	;RUN: llvm-mc -preserve-comments -n -triple rl78 < %s > %t
	;RUN: diff -b %s %t
	.text

foo:	;Comment here
	;comment here
	nop
	;if DIRECTIVE COMMENT
	; WHOLE LINE COMMENT
	cmpw ax, bc	; EOL COMMENT
	;endif
	.ident	"clang version 3.9.0"
	.section	".note.GNU-stack","",@progbits
