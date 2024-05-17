.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 4  # x1 <= 4
    addi x3, x1, 8  # x3 <= x1 + 8
    xor	x1, x1, x1
	xor	x2, x2, x2
        # Set x1 to one
	addi	x1, x1, 1 
        # Test resgister+register adds.
	add 	x2, x1, x1
	add 	x2, x2, x1
	add 	x2, x1, x2

        # test LUI
        lui     x2, 0xFFFFF

	# test immediate shifts
        srai 	x2,x2,2
        srli 	x2,x2,4
        slli 	x2,x2,2
	
        # test AUIPC
	AUIPC   x2, 0x12345

      # Load the RAM address into x7
        lui     x7, 0x70000
        
            # Test four x byte stores
        sb      x2, 0(x7)
        sb      x2, 8(x7)
        sb      x2, 4(x7)
        sb      x3, 0(x7)
        
        sh      x2, 0(x7)
        
          sh      x2, 0(x7)
        sh      x2, 4(x7)
        
          # Store it into RAM  
        sw      x2, 0(x7)
       

        # Test signed byte loads
        lb      x3, 0(x7)
          lhu     x4, 0(x7)
            lw      x5, 0(x7)
            lbu      x2, 0(x7)

        # Test signed halfword loads
        lw     x6, 0(x7)
        lw     x8, 0(x7)
        add x2,x6,x1
        

    

        

          # Load them back as a word


    # Add your own test cases here!

    slti x0, x0, -256 # this is the magic instruction to end the simulation
