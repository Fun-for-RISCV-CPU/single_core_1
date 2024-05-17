ooo_test.s:
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # demonstrating OOO-ness

    # This test is NOT exhaustive
_start:

# initialize
li x1, 10
li x2, 20



# this should take many cycles
# if this writes back to the ROB after the following instructions, you get credit for CP2
mul x3, x1, x2

# these instructions should  resolve before the multiply


halt:
    slti x0, x0, -256
