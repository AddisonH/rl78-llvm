# RUN: llvm-mc -triple rl78 %s -I %p -filetype obj -o - \
# RUN:   | llvm-readobj --symbols - | FileCheck %s

rock:
    movw ax, #42

.include "directive_end.s"

hard_place:
    movw bc, #42

# CHECK: Symbol {
# CHECK:   Name: rock
# CHECK-NOT:   Name: hard_place
