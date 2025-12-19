	#RUN: llvm-mc -preserve-comments -n -triple rl78 < %s > %t
	.text
foo:
	nop ;