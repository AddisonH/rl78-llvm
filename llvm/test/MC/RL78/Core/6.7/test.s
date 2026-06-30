# RUN: llvm-mc %s -triple=rl78 -show-encoding \
# RUN:     | FileCheck -check-prefix=CHECK-INST %s

# CHECK-INST: shr a, 1                                ; encoding: [0x31,0x1a]
shr A, 1

# CHECK-INST: shr a, 2                                ; encoding: [0x31,0x2a]
shr A, 2

# CHECK-INST: shr a, 3                                ; encoding: [0x31,0x3a]
shr A, 3

# CHECK-INST: shr a, 4                                ; encoding: [0x31,0x4a]
shr A, 4

# CHECK-INST: shr a, 5                                ; encoding: [0x31,0x5a]
shr A, 5

# CHECK-INST: shr a, 6                                ; encoding: [0x31,0x6a]
shr A, 6

# CHECK-INST: shr a, 7                                ; encoding: [0x31,0x7a]
shr A, 7


# CHECK-INST: shrw ax, 1                              ; encoding: [0x31,0x1e]
shrw AX, 1

# CHECK-INST: shrw ax, 2                              ; encoding: [0x31,0x2e]
shrw AX, 2

# CHECK-INST: shrw ax, 3                              ; encoding: [0x31,0x3e]
shrw AX, 3

# CHECK-INST: shrw ax, 4                              ; encoding: [0x31,0x4e]
shrw AX, 4

# CHECK-INST: shrw ax, 5                              ; encoding: [0x31,0x5e]
shrw AX, 5

# CHECK-INST: shrw ax, 6                              ; encoding: [0x31,0x6e]
shrw AX, 6

# CHECK-INST: shrw ax, 7                              ; encoding: [0x31,0x7e]
shrw AX, 7

# CHECK-INST: shrw ax, 8                              ; encoding: [0x31,0x8e]
shrw AX, 8

# CHECK-INST: shrw ax, 9                              ; encoding: [0x31,0x9e]
shrw AX, 9

# CHECK-INST: shrw ax, 10                              ; encoding: [0x31,0xae]
shrw AX, 10

# CHECK-INST: shrw ax, 11                             ; encoding: [0x31,0xbe]
shrw AX, 11

# CHECK-INST: shrw ax, 12                              ; encoding: [0x31,0xce]
shrw AX, 12

# CHECK-INST: shrw ax, 13                             ; encoding: [0x31,0xde]
shrw AX, 13

# CHECK-INST: shrw ax, 14                             ; encoding: [0x31,0xee]
shrw AX, 14

# CHECK-INST: shrw ax, 15                             ; encoding: [0x31,0xfe]
shrw AX, 15



# CHECK-INST: shl a, 1                                ; encoding: [0x31,0x19]
shl A, 1

# CHECK-INST: shl a, 2                                ; encoding: [0x31,0x29]
shl A, 2

# CHECK-INST: shl a, 3                                ; encoding: [0x31,0x39]
shl A, 3

# CHECK-INST: shl a, 4                                ; encoding: [0x31,0x49]
shl A, 4

# CHECK-INST: shl a, 5                                ; encoding: [0x31,0x59]
shl A, 5

# CHECK-INST: shl a, 6                                ; encoding: [0x31,0x69]
shl A, 6

# CHECK-INST: shl a, 7                                ; encoding: [0x31,0x79]
shl A, 7



# CHECK-INST: shl b, 1                                ; encoding: [0x31,0x18]
shl B, 1

# CHECK-INST: shl b, 2                                ; encoding: [0x31,0x28]
shl B, 2

# CHECK-INST: shl b, 3                                ; encoding: [0x31,0x38]
shl B, 3

# CHECK-INST: shl b, 4                                ; encoding: [0x31,0x48]
shl B, 4

# CHECK-INST: shl b, 5                                ; encoding: [0x31,0x58]
shl B, 5

# CHECK-INST: shl b, 6                                ; encoding: [0x31,0x68]
shl B, 6

# CHECK-INST: shl b, 7                                ; encoding: [0x31,0x78]
shl B, 7



# CHECK-INST: shl c, 1                                ; encoding: [0x31,0x17]
shl C, 1

# CHECK-INST: shl c, 2                                ; encoding: [0x31,0x27]
shl C, 2

# CHECK-INST: shl c, 3                                ; encoding: [0x31,0x37]
shl C, 3

# CHECK-INST: shl c, 4                                ; encoding: [0x31,0x47]
shl C, 4

# CHECK-INST: shl c, 5                                ; encoding: [0x31,0x57]
shl C, 5

# CHECK-INST: shl c, 6                                ; encoding: [0x31,0x67]
shl C, 6

# CHECK-INST: shl c, 7                                ; encoding: [0x31,0x77]
shl C, 7



# CHECK-INST: shlw ax, 1                              ; encoding: [0x31,0x1d]
shlw AX, 1

# CHECK-INST: shlw ax, 2                              ; encoding: [0x31,0x2d]
shlw AX, 2

# CHECK-INST: shlw ax, 3                              ; encoding: [0x31,0x3d]
shlw AX, 3

# CHECK-INST: shlw ax, 4                                ; encoding: [0x31,0x4d]
shlw AX, 4

# CHECK-INST: shlw ax, 5                                ; encoding: [0x31,0x5d]
shlw AX, 5

# CHECK-INST: shlw ax, 6                                ; encoding: [0x31,0x6d]
shlw AX, 6

# CHECK-INST: shlw ax, 7                                ; encoding: [0x31,0x7d]
shlw AX, 7

# CHECK-INST: shlw ax, 8                                ; encoding: [0x31,0x8d]
shlw AX, 8

# CHECK-INST: shlw ax, 9                                ; encoding: [0x31,0x9d]
shlw AX, 9

# CHECK-INST: shlw ax, 10                                ; encoding: [0x31,0xad]
shlw AX, 10

# CHECK-INST: shlw ax, 11                               ; encoding: [0x31,0xbd]
shlw AX, 11

# CHECK-INST: shlw ax, 12                               ; encoding: [0x31,0xcd]
shlw AX, 12

# CHECK-INST: shlw ax, 13                               ; encoding: [0x31,0xdd]
shlw AX, 13

# CHECK-INST: shlw ax, 14                               ; encoding: [0x31,0xed]
shlw AX, 14

# CHECK-INST: shlw ax, 15                               ; encoding: [0x31,0xfd]
shlw AX, 15


# CHECK-INST: shlw bc, 1                               ; encoding: [0x31,0x1c]
shlw BC, 1

# CHECK-INST: shlw bc, 2                                ; encoding: [0x31,0x2c]
shlw BC, 2

# CHECK-INST: shlw bc, 3                                ; encoding: [0x31,0x3c]
shlw BC, 3

# CHECK-INST: shlw bc, 4                                ; encoding: [0x31,0x4c]
shlw BC, 4

# CHECK-INST: shlw bc, 5                                ; encoding: [0x31,0x5c]
shlw BC, 5

# CHECK-INST: shlw bc, 6                                ; encoding: [0x31,0x6c]
shlw BC, 6

# CHECK-INST: shlw bc, 7                                ; encoding: [0x31,0x7c]
shlw BC, 7

# CHECK-INST: shlw bc, 8                                ; encoding: [0x31,0x8c]
shlw BC, 8

# CHECK-INST: shlw bc, 9                                ; encoding: [0x31,0x9c]
shlw BC, 9

# CHECK-INST: shlw bc, 10                                ; encoding: [0x31,0xac]
shlw BC, 10

# CHECK-INST: shlw bc, 11                               ; encoding: [0x31,0xbc]
shlw BC, 11

# CHECK-INST: shlw bc, 12                               ; encoding: [0x31,0xcc]
shlw BC, 12

# CHECK-INST: shlw bc, 13                               ; encoding: [0x31,0xdc]
shlw BC, 13

# CHECK-INST: shlw bc, 14                               ; encoding: [0x31,0xec]
shlw BC, 14

# CHECK-INST: shlw bc, 15                               ; encoding: [0x31,0xfc]
shlw BC, 15



# CHECK-INST: sar a, 1                               ; encoding: [0x31,0x1b]
sar A, 1

# CHECK-INST: sar a, 2                                ; encoding: [0x31,0x2b]
sar A, 2

# CHECK-INST: sar a, 3                                ; encoding: [0x31,0x3b]
sar A, 3

# CHECK-INST: sar a, 4                                ; encoding: [0x31,0x4b]
sar A, 4

# CHECK-INST: sar a, 5                                ; encoding: [0x31,0x5b]
sar A, 5

# CHECK-INST: sar a, 6                                ; encoding: [0x31,0x6b]
sar A, 6

# CHECK-INST: sar a, 7                                ; encoding: [0x31,0x7b]
sar A, 7



# CHECK-INST: sarw ax, 1                              ; encoding: [0x31,0x1f]
sarw AX, 1

# CHECK-INST: sarw ax, 2                              ; encoding: [0x31,0x2f]
sarw AX, 2

# CHECK-INST: sarw ax, 3                                ; encoding: [0x31,0x3f]
sarw AX, 3

# CHECK-INST: sarw ax, 4                                ; encoding: [0x31,0x4f]
sarw AX, 4

# CHECK-INST: sarw ax, 5                                ; encoding: [0x31,0x5f]
sarw AX, 5

# CHECK-INST: sarw ax, 6                                ; encoding: [0x31,0x6f]
sarw AX, 6

# CHECK-INST: sarw ax, 7                                ; encoding: [0x31,0x7f]
sarw AX, 7

# CHECK-INST: sarw ax, 8                                ; encoding: [0x31,0x8f]
sarw AX, 8

# CHECK-INST: sarw ax, 9                                ; encoding: [0x31,0x9f]
sarw AX, 9

# CHECK-INST: sarw ax, 10                                ; encoding: [0x31,0xaf]
sarw AX, 10

# CHECK-INST: sarw ax, 11                               ; encoding: [0x31,0xbf]
sarw AX, 11

# CHECK-INST: sarw ax, 12                               ; encoding: [0x31,0xcf]
sarw AX, 12

# CHECK-INST: sarw ax, 13                               ; encoding: [0x31,0xdf]
sarw AX, 13

# CHECK-INST: sarw ax, 14                               ; encoding: [0x31,0xef]
sarw AX, 14

# CHECK-INST: sarw ax, 15                               ; encoding: [0x31,0xff]
sarw AX, 15
