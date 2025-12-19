# RUN: llvm-mc -triple=rl78 < %s -show-encoding \
# RUN:     | FileCheck -check-prefix=INSTR -check-prefix=FIXUP %s
# RUN: llvm-mc -filetype=obj -triple=rl78 < %s \
# RUN:     | llvm-readobj -r - | FileCheck -check-prefix=RELOC %s

.extern addr16bit
.extern addr20bit
.addr20bit:
    .fill 0x100
    
.extern _test

.set addr20, 82
.set addr16, 81
    # TODO: R_RL78_DIR3U
    //and1 CY,_bsym

    # R_RL78_DIR8U
    # INSTR: addw sp, #word
    # RELOC: R_RL78_DIR8U
    # FIXUP: fixup A - offset: 1, value: word, kind: fixup_RL78_DIR8U
    ADDW SP, #word

    # R_RL78_DIR16U
    # INSTR: br !addr16bit
    # RELOC: R_RL78_DIR16U
    # FIXUP: fixup A - offset: 1, value: addr16bit, kind: fixup_RL78_DIR16U
    BR !addr16bit

    # R_RL78_DIR20U
    # INSTR: br !!addr16bit
    # RELOC: R_RL78_DIR20U
    # FIXUP: fixup A - offset: 1, value: addr16bit, kind: fixup_RL78_DIR20U
    BR !!addr16bit

    # R_RL78_DIR20U_16
    # INSTR: mov es:!_ac, #3
    # RELOC: R_RL78_DIR20U_16
    # FIXUP: fixup A - offset: 2, value: _ac, kind: fixup_RL78_DIR20U_16
    mov es:!(_ac), #3

    # R_RL78_DIR20UW_16
    # INSTR: movw es:!_ac, ax
    # RELOC: R_RL78_DIR20UW_16
    # FIXUP: fixup A - offset: 2, value: _ac, kind: fixup_RL78_DIR20UW_16
    movw es:!(_ac), ax

    # R_RL78_DIR32U
    # INSTR: .long var1
    # RELOC: R_RL78_DIR32U
    .long var1

    # TODO: R_RL78_DIR8U_MIR
    
    # TODO: R_RL78_DIR16U_MIR

    # TODO: R_RL78_DIR16UW_MIR

    # R_RL78_DIR8U_SAD
    # INSTR: mov a, addr16bit
    # RELOC: R_RL78_DIR8U_SAD
    # FIXUP: fixup A - offset: 1, value: addr16bit, kind: fixup_RL78_DIR8U_SAD
    mov A, addr16bit

    # R_RL78_DIR8UW_SAD
    # INSTR: movw ax, addr16bit
    # RELOC: R_RL78_DIR8UW_SAD
    # FIXUP: fixup A - offset: 1, value: addr16bit, kind: fixup_RL78_DIR8UW_SAD
    movw AX, addr16bit

    # R_RL78_DIR16U_RAM
    # INSTR: add a, !addr16bit
    # RELOC: R_RL78_DIR16U_RAM
    # FIXUP: fixup A - offset: 1, value: addr16bit, kind: fixup_RL78_DIR16U_RAM
    add A,!addr16bit

    # R_RL78_DIR16UW_RAM
    # INSTR: addw ax, !addr16bit
    # RELOC: R_RL78_DIR16UW_RAM
    # FIXUP: fixup A - offset: 1, value: addr16bit, kind: fixup_RL78_DIR16UW_RAM
    addw AX,!addr16bit

    # R_RL78_DIR8S_PCREL
    # INSTR: br $addr16bit
    # RELOC: R_RL78_DIR8S_PCREL
    # FIXUP: fixup A - offset: 1, value: addr16bit, kind: fixup_RL78_DIR8S_PCREL
    BR $addr16bit

    # R_RL78_DIR16S_PCREL
    # INSTR: br $!addr20bit
    # RELOC: R_RL78_DIR16S_PCREL
    # FIXUP: fixup A - offset: 1, value: addr20bit, kind: fixup_RL78_DIR16S_PCREL
    BR $!addr20bit

    # R_RL78_DIR_CALLT
    # INSTR: callt [addr16bit]
    # RELOC: R_RL78_DIR_CALLT
    # FIXUP: fixup A - offset: 1, value: addr16bit, kind: fixup_RL78_DIR_CALLT
    CALLT [addr16bit]

    # TODO: R_RL78_ABS3U

    # R_RL78_ABS8U
    # INSTR: add a, #LOW(addr16bit-addr16bit)
    # RELOC: R_RL78_ABS8U
    # FIXUP: fixup E - offset: 1, value: 0, kind: fixup_RL78_ABS8U
    add A,#LOW(addr16bit - addr16bit)

    # TODO: R_RL78_ABS8UW
    
    # R_RL78_ABS16U
    # INSTR: movw es:!LOWW(_ac), ax
    # RELOC: R_RL78_ABS16U
    # FIXUP: fixup B - offset: 2, value: 0, kind: fixup_RL78_ABS16U
    movw es:!LOWW(_ac), ax

    # TODO: R_RL78_ABS16UW

    # R_RL78_ABS20U
    # INSTR: br !!_sym-_zsym
    # RELOC: R_RL78_ABS20U
    # FIXUP: fixup D - offset: 1, value: 0, kind: fixup_RL78_ABS20U
    br !!(_sym - _zsym)
    
    # TODO: R_RL78_ABS20U_16

    # TODO: R_RL78_ABS20UW_16

    # TODO: R_RL78_ABS32U

    # TODO: R_RL78_ABS8S_PCREL

    # TODO: R_RL78_ABS16S_PCREL

    # TODO: R_RL78_ABS_CALLT

    # TODO: R_RL78_REF

    # R_RL78_SYM
    # INSTR: add a, sym-zsym
    # RELOC: R_RL78_SYM
    # FIXUP: fixup A - offset: 1, value: sym, kind: fixup_RL78_SYM
    add A, (sym - zsym)

    # TODO: R_RL78_SYM_MIR
    
    # R_RL78_OPadd
    # INSTR: addw ax, #(HIGHW(HIGH(addr16bit)))+1
    # RELOC: R_RL78_OPadd
    # FIXUP: fixup D - offset: 1, value: 0, kind: fixup_RL78_OPadd
    addw ax, #highw(high(addr16bit)) + 1

    # R_RL78_OPsub
    # INSTR: movw ax, #LOW(addr16bit-addr16bit)
    # RELOC: R_RL78_OPsub
    # FIXUP: fixup C - offset: 1, value: 0, kind: fixup_RL78_OPsub
    movw ax, #low(addr16bit - addr16bit)

    # R_RL78_OPsctsize
    # INSTR: movw ax, SIZEOF(.text)
    # RELOC: R_RL78_OPsctsize
    # FIXUP: fixup A - offset: 1, value: .text, kind: fixup_RL78_OPsctsize
    movw ax, sizeof(.text)

    # R_RL78_OPscttop
    # INSTR: movw ax, STARTOF(.text)
    # RELOC: R_RL78_OPscttop
    # FIXUP: fixup A - offset: 1, value: .text, kind: fixup_RL78_OPscttop
    movw ax, STARTOF(.text)

    # R_RL78_OPlowH
    # INSTR: add a, #HIGH(_sym)
    # RELOC: R_RL78_OPlowH
    # FIXUP: fixup A - offset: 1, value: _sym, kind: fixup_RL78_OPlowH
    add A, #high(_sym)

    # R_RL78_OPlowL
    # INSTR: add a, #LOW(_sym)
    # RELOC: R_RL78_OPlowL
    # FIXUP: fixup A - offset: 1, value: _sym, kind: fixup_RL78_OPlowL
    add A, #low(_sym)

    # R_RL78_OPhighW
    # INSTR: add a, #HIGHW(_sym)
    # RELOC: R_RL78_OPhighW
    # FIXUP: fixup A - offset: 1, value: _sym, kind: fixup_RL78_OPhighW
    add A, #highw(_sym)

    # R_RL78_OPlowW
    # INSTR: add a, #LOWW(_sym)
    # RELOC: R_RL78_OPlowW
    # FIXUP: fixup A - offset: 1, value: _sym, kind: fixup_RL78_OPlowW
    add A, #loww(_sym)
    
    # R_RL78_OPhighW_MIR
    # INSTR: add a, !MIRHW(_msym)
    # RELOC: R_RL78_OPhighW_MIR
    # FIXUP: fixup A - offset: 1, value: _msym, kind: fixup_RL78_OPhighW_MIR
    add A, !mirhw(_msym)

    # R_RL78_OPlowW_MIR
    # INSTR: add a, !MIRLW(_msym)
    # RELOC: R_RL78_OPlowW_MIR
    # FIXUP: fixup A - offset: 1, value: _msym, kind: fixup_RL78_OPlowW_MIR
    add A, !mirlw(_msym)

    # R_RL78_OPlowW_SMIR
    # INSTR: movw ax, SMRLW(.text)
    # RELOC: R_RL78_OPlowW_SMIR
    # FIXUP: fixup A - offset: 1, value: .text, kind: fixup_RL78_OPlowW_SMIR
    movw ax, smrlw(.text)

    # TODO: R_RL78_OPmir

    # R_RL78_OPABSlowH
    # INSTR: add a, #HIGH(LOWW(addr16bit))
    # RELOC: R_RL78_OPABSlowH
    # FIXUP: fixup B - offset: 1, value: 0, kind: fixup_RL78_OPABSlowH
    add A, #HIGH(LOWW(addr16bit))

    # R_RL78_OPABSlowL
    # INSTR: add a, #LOW(LOWW(addr16bit))
    # RELOC: R_RL78_OPABSlowL
    # FIXUP: fixup B - offset: 1, value: 0, kind: fixup_RL78_OPABSlowL
    add A, #LOW(LOWW(addr16bit))

    # TODO: R_RL78_OPABSh

    # R_RL78_OPABSlowW
    # INSTR: add a, #LOWW(addr16bit-addr16bit)
    # RELOC: R_RL78_OPABSlowW
    # FIXUP: fixup D - offset: 1, value: 0, kind: fixup_RL78_OPABSlowW
    add A, #LOWW(addr16bit - addr16bit)

    # R_RL78_OPABShighW
    # INSTR: add a, #HIGHW(addr16bit-addr16bit)
    # RELOC: R_RL78_OPABShighW
    # FIXUP: fixup D - offset: 1, value: 0, kind: fixup_RL78_OPABShighW
    add A, #HIGHW(addr16bit - addr16bit)
