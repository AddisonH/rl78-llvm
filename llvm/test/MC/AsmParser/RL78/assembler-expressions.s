# RUN: not llvm-mc -triple rl78 %s 2>&1 | FileCheck %s --check-prefix=ASM-ERR --implicit-check-not=error:
# RUN: llvm-mc -filetype=obj -triple rl78 %s | llvm-objdump -j .data  -s - | FileCheck %s --check-prefix=OBJDATA
# RUN: llvm-mc -filetype=obj -triple rl78 %s | llvm-objdump -j .text -s - | FileCheck %s --check-prefix=OBJTEXT
.data

# OBJDATA: Contents of section .data
# OBJDATA-NEXT: 0000 aa01aa05 06000000 08ff

foo1:
# ASM-ERR: :[[#@LINE+1]]:5: error: expected absolute expression
.if . - foo1 == 0
    .byte 0xaa
.else
    .byte 0x00
.endif

foo2:
    .byte 1
# ASM-ERR: :[[#@LINE+1]]:5: error: expected absolute expression
.if foo2 - . == -1
    .byte 0xaa
.else
    .byte 0x00
.endif

foo3:
    .byte 5
# ASM-ERR: [[@LINE+1]]:5: error: expected absolute expression
.if . - foo3 == 1
   .byte 6
.else
   .byte 7
.endif

foo4:
.byte 0
.space 2
# ASM-ERR: :[[#@LINE+1]]:5: error: expected absolute expression
.if . - foo4 == 3
    .byte 8
.else
    .byte 9
.endif

.byte 0xff

# nop is a fixed size instruction so this should pass.

# OBJTEXT: Contents of section .text
# OBJTEXT-NEXT: 0000 000000c1 00000078 56341278 56341200

.text
text1:
# ASM-ERR: [[@LINE+1]]:5: error: expected absolute expression
.if . - text1 == 0
	nop
.endif

text2:
        nop
# ASM-ERR: [[@LINE+1]]:5: error: expected absolute expression
.if . - text2 == 1
	nop
.else
	ret
.endif
	push ax
	nop
	nop
	nop
# No additional errors.
#
# ASM-ERR-NOT: {{[0-9]+}}:{{[0-9]+}}: error:


text3:
	.long 0x12345678
text4:
	.fill (text4-text3)/4, 4, 0x12345678
	nop





	
