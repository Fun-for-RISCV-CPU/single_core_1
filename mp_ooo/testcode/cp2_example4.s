.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
   	xor	x1, x1, x1
	xor	x2, x2, x2
        # Set x1 to one
	addi	x1, x1, 1 
        # Test resgister+register adds.
        addi x0, x1, 2
        addi x0, x1, 2
	addi x0, x1, 2
 add x5, x0, x0
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

        #######################################
        # Testing different size stores
        #######################################
        # Load the RAM address into x7
        lui     x7, 0x70000

        # Test four x byte stores
        sb      x2, 0(x7)
        sb      x2, 1(x7)
        sb      x2, 2(x7)
        sb      x2, 3(x7)

        # Load them back as a word
        lw	x3, 0(x7)

        # Test two x halfword stores
        sh      x2, 0(x7)
        sh      x2, 2(x7)

        # Load them back as a word
        lw	x3, 0(x7)
 
        #Create a new test value 0x89ABCDEF
        lui     x2, 0x89ABD
        addi    x2, x2, 0xFFFFFDEF

           # Store it into RAM  
        sw      x2, 0(x7)

        # Load them back as a word
        lw      x2, 0(x7)
        lw      x0, 0(x7)
        add x25, x0, x0
        add x25, x0, x0
        add x25, x0, x0
        # empty out x3 and test relative jump
      



    slti x0, x0, -256 # this is the magic instruction to end the simulation
