# RUN: llvm-mc -filetype=obj -defsym=I=4 -triple rl78 %s | llvm-objdump --triple=rl78 -s - | FileCheck --check-prefix="CHECK" %s
# RUN: llvm-mc -filetype=obj -defsym=I=2 -triple rl78 %s -o /dev/null 2>&1 | FileCheck --check-prefix="CHECK-ERR" %s



# CHECK: Contents of section .text
# CHECK-NEXT: 0000 ed0000cc 90909090 90909090 90909090

# Make sure we emit in correct endianness.

# CHECK: Contents of section .data
# CHECK-NEXT: 0000 78563412 78563412 78563412

.text
foo:
br !bar2
# CHECK-ERR: [[@LINE+1]]:7: warning: '.fill' directive with negative repeat count has no effect
.fill ((I+foo) - .), 1, 0xcc
bar:
 .space 128, 0x90
bar2:
.byte 0xff

# This fill length is not known at assembler time.

.if (I==4)

.data
.long 0x12345678
.fill ((foo+8)-bar), 4, 0x12345678

.endif
