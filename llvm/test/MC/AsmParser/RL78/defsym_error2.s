# RUN: not llvm-mc -filetype=obj -triple=rl78 -defsym a=a %s 2>&1 | FileCheck %s
# CHECK: error: value is not an integer: a
