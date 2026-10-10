# REQUIRES: rl78
## --relax-callt gives the functions called at least three times an entry in
## the CALLT table and turns their calls into "callt [addr5]" (2 bytes). The
## entries follow the input files' own .callt0 entries. A function called less
## often keeps "call !addr16".

# RUN: llvm-mc -filetype=obj -triple=rl78 -mattr=+relax %s -o %t.o
# RUN: echo 'SECTIONS { .callt0 0x80 : { *(.callt0) } .text 0x100 : { *(.text) } }' > %t.ld
# RUN: ld.lld --relax --relax-callt -T %t.ld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s --check-prefix=CALLT
# RUN: llvm-objdump -s -j .callt0 %t | FileCheck %s --check-prefix=TABLE
# RUN: ld.lld --relax -T %t.ld %t.o -o %t.no
# RUN: llvm-objdump -d --no-show-raw-insn %t.no | FileCheck %s --check-prefix=NOCALLT

## Without a table at 0x80-0xBF the calls stay as they are.
# RUN: echo 'SECTIONS { .text 0x100 : { *(.text) } .callt0 0x1000 : { *(.callt0) } }' > %t2.ld
# RUN: ld.lld --relax --relax-callt -T %t2.ld %t.o -o %t2
# RUN: llvm-objdump -d --no-show-raw-insn %t2 | FileCheck %s --check-prefix=NOCALLT

# CALLT:      100: callt [0x0082]
# CALLT-NEXT: 102: callt [0x0082]
# CALLT-NEXT: 104: callt [0x0082]
# CALLT-NEXT: 106: call !0x10d <_g>
# CALLT-NEXT: 109: call !0x10d <_g>
# CALLT-NEXT: 10c: ret
# CALLT:      10d: ret
# CALLT:      10e: ret

# TABLE: 0080 0d010e01

# NOCALLT:      call !{{.*}} <_f>
# NOCALLT-NEXT: call !{{.*}} <_f>
# NOCALLT-NEXT: call !{{.*}} <_f>
# NOCALLT-NEXT: call !{{.*}} <_g>
# NOCALLT-NEXT: call !{{.*}} <_g>

	.text
	.globl	_start
_start:
	call	!!_f
	call	!!_f
	call	!!_f
	call	!!_g
	call	!!_g
	ret
_g:
	ret
_f:
	ret

	.section	.callt0,"a",@progbits
	.short	_g
