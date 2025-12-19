# RUN: llvm-mc -triple rl78 %s | FileCheck %s

# CHECK: TEST0:
# CHECK: .byte 0
TEST0:  
        .byte 0

# CHECK: TEST1:
# CHECK: .short 3
TEST1:  
        .short 3

# CHECK: TEST2:
# CHECK: .long 8
TEST2:  
        .long 8

TEST5:
        .value 8
# CHECK: TEST5:
# CHECK: .short 8

TEST6:
        .byte 'c'
        .byte '\''
        .byte '\\'
        .byte '\#'
        .byte '\t'
        .byte '\n'
        .byte '\r'
        .byte '\f'
        .byte '\"'

# CHECK: TEST6
# CHECK:   .byte   99
# CHECK:   .byte   39
# CHECK:   .byte   92
# CHECK:   .byte   35
# CHECK:   .byte   9
# CHECK:   .byte   10
# CHECK:   .byte   13
# CHECK:   .byte   12
# CHECK:   .byte   34

TEST7:
        .byte 1, 2, 3, 4
# CHECK: TEST7
# CHECK:   .byte   1
# CHECK:   .byte   2
# CHECK:   .byte   3
# CHECK:   .byte   4

TEST8:
        .long 0x200000UL+1
        .long 0x200000L+1
# CHECK: TEST8
# CHECK: .long 2097153
# CHECK-NEXT: .long 2097153


