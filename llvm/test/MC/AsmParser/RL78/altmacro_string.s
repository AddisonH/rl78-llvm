# RUN: llvm-mc -triple rl78  %s| FileCheck %s

# This test checks the altmacro string delimiter '<' and '>'.

.altmacro

# Test #1:
# You can delimit strings with matching angle brackets '<' '>'.
# If an argument begins with '<' and ends with '>'.
# The argument is considered as a string.

# CHECK: simpleCheck:
.macro simple_check_0 name
    \name:
   addw ax, #5
.endm

simple_check_0 <simpleCheck>

# Test #2:
# Except adding new string marks '<..>', a regular macro behavior is expected.

# CHECK:  simpleCheck0:
# CHECK: addw    ax, #0
.macro concat string1 string2 string3
   \string1\string2\string3:
        addw ax, #\string3
.endm

concat <simple>,<Check>,<0>

# Test #3:
# The altmacro cannot affect the regular less/greater behavior.

# CHECK: addw ax, #-1
# CHECK: addw ax, #0

.macro fun3 arg1 arg2
   addw ax, #\arg1
   addw ax, #\arg2
.endm

fun3 5<6 , 5>8

# Test #4:
# If a comma is present inside an angle brackets,
# the comma considered as a character and not as a separator.
# This check checks the ability to split the string to different
# arguments according to the use of the comma.
# Fun2 sees the comma as a character.
# Fun3 sees the comma as a separator.

# CHECK: addw ax, #5
# CHECK: addw ax, #6
.macro fun2 arg
   fun3 \arg
.endm

fun2 <5,6>

# Test #5:
# If argument begin with '<' and there is no '>' to close it.
# A regular macro behavior is expected.

# CHECK: addw ax, #4
.macro fun4 arg1 arg2
   .if \arg2\arg1
   addw ax, #\arg2
   .endif
.endm

fun4 <5,4
.noaltmacro
