.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.
 lui     x7, 0x70000
        
            # Test four x byte stores
        sb      x2, 0(x7)
        sb      x2, 8(x7)
        sb      x2, 4(x7)
        sb      x3, 0(x7)
        




    # Add your own test cases here!

    slti x0, x0, -256 # this is the magic instruction to end the simulation
