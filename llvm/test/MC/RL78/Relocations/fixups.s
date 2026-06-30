# RUN: llvm-mc -triple=rl78 < %s -show-encoding \
# RUN:      | FileCheck -check-prefix=INSTR %s
# RUN: llvm-mc -filetype=obj -triple=rl78 < %s \
# RUN:     | llvm-objdump -d - | FileCheck -check-prefix=DISASS %s


.equ word, 79
.equ addr16, 0xffff
.equ addr20, 0xfffff
.equ sadd, 0xffe20
.equ addr_callt, 0x00082

# fixup_RL78_DIR8U
# INSTR: addw sp
# DISASS: 10 4f         addw sp, #79
ADDW SP, #word

# fixup_RL78_DIR8U_SAD
# INSTR: mov a, 0xffe20
# DISASS: 8d 20         mov a, 0xffe20
mov A, sadd

# fixup_RL78_DIR8UW_SAD
# INSTR: movw ax, 0xffe20
# DISASS: ad 20         movw ax, 0xffe20
movw AX, sadd

# fixup_RL78_DIR16U
# INSTR: br !0xffff
# DISASS: ed ff ff      br !0xffff <.text+0xffff>
BR !addr16

# fixup_RL78_DIR16U_RAM
# INSTR: add a, !0xfffff
# DISASS: 0f ff ff      add a, !0xfffff
add A,!addr16

# fixup_RL78_DIR16UW_RAM
# INSTR: addw ax, !0xfffff
# DISASS: 02 ff ff      addw ax, !0xfffff
addw AX,!addr16

# fixup_RL78_DIR20U
# INSTR: br !!0xfffff
# DISASS: ec ff ff 0f   br !!0xfffff <.text+0xfffff>
BR !!addr20

# fixup_RL78_DIR20U_16
# INSTR: mov es:!0xffff, #3
# DISASS: 11 cf ff ff 03        mov es:!0xffff, #3
mov es:!(addr16), #3

# fixup_RL78_DIR20UW_16
# INSTR: movw es:!0xffff, ax
# DISASS: 11 bf ff ff   movw es:!0xffff, ax
movw es:!(addr16), ax

# fixup_RL78_DIR_CALLT
# INSTR: callt [0x0082]
# DISASS: 61 94         callt [0x0082]
CALLT [addr_callt]
