# RUN: not llvm-mc -filetype=obj -triple=rl78 -defsym aaoeuaoeu %s 2>&1 | FileCheck %s
# CHECK: defsym must be of the form: sym=value
