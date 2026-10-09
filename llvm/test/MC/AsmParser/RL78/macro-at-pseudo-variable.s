# RUN: llvm-mc -triple rl78 %s | FileCheck %s

.macro A
  addw  ax, #1\@
.endm

.macro B
  subw  ax, #1\@
.endm

  A
# CHECK: addw  ax, #10
  A
# CHECK: addw  ax, #11
  B
# CHECK: subw  ax, #12
  B
# CHECK: subw  ax, #13

# The following uses of \@ are undocumented, but valid:
.irpc foo,234
  addw  ax, #\foo\@
.endr
# CHECK: addw  ax, #24
# CHECK: addw  ax, #34
# CHECK: addw  ax, #44

.irp reg,ax,bc
  movw  \reg, #2\@
.endr
# CHECK: movw ax, #24
# CHECK: movw bc, #24

# Test that .irp(c) and .rep(t) do not increase \@.
# Only the use of A should increase \@, so we can test that it increases by 1
# each time.

.irpc foo,123
  subw  ax, #\foo
.endr

  A
# CHECK: addw  ax, #14

.irp reg,ax,bc
  movw  \reg, #4
.endr

  A
# CHECK: addw  ax, #15

.rept 2
  subw  ax, #5
.endr

  A
# CHECK: addw  ax, #16

.rep 3
  subw  ax, #5
.endr

  A
# CHECK: addw  ax, #17
