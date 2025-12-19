# RUN: not llvm-mc -triple rl78 -filetype=obj -o /dev/null %s 2>&1 | FileCheck %s

# CHECK: error: Undefined temporary symbol
foo:
  br $.Lbar
