// RUN: llvm-mc -triple rl78 %s 2>&1 | FileCheck %s
# ensure that single '#' comments are worink as expected on x86 darwin
.p2align 3            ; test single hash after align
// CHECK: .p2align 3
foo:                ; single hash should be ignored as comment
// CHECK-LABEL: foo:
    movw ax, bc ; same after an instruction
// CHECK:  movw ax, bc
#   movl %esp, %ebp ## start of the line
// CHECK-NOT: movl %esp, %ebp
    # movl %esp, %ebp ## not quite start of the line
// CHECK-NOT: movl %esp, %ebp
bar:
// CHECK-LABEL: bar:
