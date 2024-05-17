.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.
    
    xor	x1, x1, x1
	xor	x2, x2, x2
        # Set x1 to one
	addi	x1, x1, 1 
        # Test resgister+register adds.
	add 	x2, x1, x1
	add 	x2, x2, x1
	add 	x2, x1, x2

    

    #######################################
    # Testing different size stores
    #######################################
    # Load the RAM address into x7
    lui     x7, 0x70000
    lui     x3, 0x76000
    lui     x4, 0x77000
    lui     x5, 0x78000
    lui     x6, 0x79000

    # Test four x byte stores
    sw      x2, 0(x7)
    
      mul x2, x2, x2
    mul x2, x2, x2
     mul x2, x2, x2
   

    sw     x2, 0(x4)
    
    
    sw      x2, 0(x5)
    
    
    
    sw      x6, 0(x7)

    lw	x9, 0(x5)
    
  

    # Add your own test cases here!

    slti x0, x0, -256 # this is the magic instruction to end the simulation
