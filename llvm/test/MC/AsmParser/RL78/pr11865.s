// RUN: llvm-mc -triple rl78 %s

i:
        .long    g
g = h
h = i
