// RUN: not llvm-mc -filetype=asm -triple rl78 %s -o %t 2>%t.out
// RUN: FileCheck -input-file=%t.out %s

.cfi_startproc
// CHECK: Unfinished frame
