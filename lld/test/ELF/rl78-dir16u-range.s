# REQUIRES: rl78
## R_RL78_DIR16U takes a 16-bit value, signed or not, or a near address:
## one in 0xF0000-0xFFFFF is written as its low 16 bits.

# RUN: llvm-mc -filetype=obj -triple=rl78 %s -o %t.o
# RUN: ld.lld --defsym=near=0xffe20 --defsym=neg=-1 --defsym=low=0x1234 \
# RUN:   --defsym=bad=0x1234 %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s
# RUN: not ld.lld --defsym=near=0xffe20 --defsym=neg=-1 --defsym=low=0x1234 \
# RUN:   --defsym=bad=0x12345 %t.o -o /dev/null 2>&1 | FileCheck %s --check-prefix=ERR

# CHECK:      movw ax, #65056
# CHECK-NEXT: movw ax, #65535
# CHECK-NEXT: movw ax, #4660
# CHECK-NEXT: movw ax, #4660

# ERR: error: {{.*}}relocation R_RL78_DIR16U out of range: 74565 is not in [-32768, 1048575]; references 'bad'
# ERR-NOT: error:

.text
.global _start
_start:
  movw ax, #near
  movw ax, #neg
  movw ax, #low
  movw ax, #bad
