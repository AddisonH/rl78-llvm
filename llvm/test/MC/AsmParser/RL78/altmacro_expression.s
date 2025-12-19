# RUN: llvm-mc -triple rl78 %s | FileCheck %s

# Checking that the '%' was evaluated as a string first
# In a fail scenario: The asmprint will print: addw $%(1+4), ax

# CHECK:  addw ax, #5
.altmacro
.macro percent_expr arg
    addw ax, #\arg
.endm

percent_expr %(1+4)


# Checking that the second '%' acts as modulo operator
# The altmacro percent '%' must be located before the first argument
# If a percent is located in the middle of the estimated argument without any
# '%' in the beginning , error will be generated.
# The second percent '%' after the first altmacro percent '%' is a regular operator.

# CHECK:  addw ax, #1
.macro inner_percent arg
    addw ax, #\arg
.endm

inner_percent %(1%4)


# Checking for nested macro
# The first argument use is for the calling function and the second use is for the evaluation.

# CHECK:  addw ax, #1
.macro macro_call_0 number
    addw ax, #\number
.endm

.macro macro_call_1 number
    macro_call_\number %(\number + 1)
.endm

macro_call_1 %(1-1)


# Checking the ability to pass a number of arguments.
# The arguments can be separated by ',' or not.

# CHECK: label013:
# CHECK:  addw ax, #0 
# CHECK:  addw ax, #1
# CHECK:  addw ax, #3

# CHECK: label014:
# CHECK:  addw ax, #0
# CHECK:  addw ax, #1
# CHECK:  addw ax, #4

.macro multi_args_macro arg1 arg2 arg3
    label\arg1\arg2\arg3:
	addw ax, #\arg1
	addw ax, #\arg2
	addw ax, #\arg3
.endm

multi_args_macro %(1+4-5) 1 %2+1
multi_args_macro %(1+4-5),1,%4%10
