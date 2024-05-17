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

    # test LUI
    lui     x2, 0xFFFFF

	# test immediate shifts
    srai 	x2,x2,2
    srli 	x2,x2,4
    slli 	x2,x2,2

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
        lui     x7, 0x70004
        AUIPC   x7, 0x12345
        lui     x7, 0x70000
    lw	x3, 0(x7)
    
        add x9, x10, x3

    # Test two x halfword stores
    sh      x2, 0(x7)
    sh      x2, 2(x7)
    sh      x9, 0(x7)
    sh      x9, 2(x7)
    # Load them back as a word
    lw	x3, 0(x7)

    #Create a new test value 0x89ABCDEF
    lui     x2, 0x0
    addi    x2, x2, 0xFFFFFFFF

    # Store it into RAM  
   # sw      x2, 0(x7)
     sh      x2, 0(x7)
    sh      x2, 2(x7)
    sb      x2, 0(x7)
    sb      x2, 1(x7)
    sb      x2, 2(x7)
    sb      x2, 3(x7)


    # Load them back as a word
    lw      x3, 0(x7)
    
          lui     x7, 0x70004
        AUIPC   x7, 0x12345
        lui     x7, 0x70000
        
    
        add x9, x10, x3


    # Test signed halfword loads
    lh      x2, 0(x7)
    lh      x2, 2(x7)

    # Test signed byte loads
    lb      x2, 0(x7)
    lb      x2, 1(x7)
    lb      x2, 2(x7)
    lb      x2, 3(x7)

    # Test unsigned halfword loads
    lhu     x2, 0(x7)
    lhu     x2, 2(x7)

    # Test unsigned byte loads
    lbu     x2, 0(x7)
    lbu     x2, 1(x7)
    lb     x2, 2(x7)
    lb     x2, 3(x7)
    
    
     add x2,x2,x2
    add x2, x2, x2
    add x2,x2,x2
    add x2, x2, x2
    
    
    add x2, x2, x2
    #lw      x7, 0(x7)
   # add x7, x2, x7
    
    # Setup for reg <= reg op reg instructions
    lui	x2, 0x66666
    addi	x2, x2, 0x666

    lui	x3, 0xCCCCD
    addi	x3, x3, 0xFFFFFCCC

    # reg <= reg op reg instructions
    add	x4, x2, x3
    add	x4, x3, x2
    sub	x4, x2, x3
    sub	x4, x3, x2
    sll	x4, x2, x3
    sll	x4, x3, x2
    slt	x4, x2, x3
    slt	x4, x3, x2
    sltu	x4, x2, x3
    sltu	x4, x3, x2
    xor	x4, x2, x3
    xor	x4, x3, x2
    srl	x4, x2, x3
    srl	x4, x3, x2
    sra	x4, x2, x3
    sra	x4, x3, x2
    or	x4, x2, x3
    or	x4, x3, x2
    and	x4, x2, x3
    and	x4, x3, x2

    # reg <= reg op immediate instructions
    addi	x4, x3, 0x666
    slti	x4, x3, 0x666
    sltiu	x4, x3, 0x666
    xori 	x4, x3, 0x666
    ori 	x4, x3, 0x666
    andi 	x4, x3, 0x666
    slli 	x4, x3, 6
    srli 	x4, x3, 6
    srai 	x4, x3, 6

    # empty out x3 and test relative jump
        andi 	x3, x0, 0
        jal     x4, tmp0
		ori 	x3, x3, 1
        ori 	x3, x3, 1
tmp0:	ori 	x3, x3, 2
        ori 	x3, x3, 4
        # Testing conditional branckes
        xor 	x2, x2, x2
        addi    x3, x2, 0x8
        addi    x4, x2, 0x8

        auipc   x1, 0
        add     x1, x1, 0x10
        jalr    x1, x1, 0
        ori     x3, x3, 4
        ori     x3, x3, 4
        ori     x3, x3, 4
        ori     x3, x3, 5
        xor 	x2, x2, x2
        addi    x3, x2, 0x8
        addi    x4, x2, 0x8
        # Test conditionals with rboth registers = 0x8
        beq     x3, x4, tmp1
        ori     x2, x2, 1
tmp1:	bne     x3, x4, tmp2        
        ori     x2, x2, 2
tmp2:	blt     x3, x4, tmp3        
        ori     x2, x2, 4
tmp3:	bge     x3, x4, tmp4        
        ori     x2, x2, 8
tmp4:	bltu 	x3, x4, tmp5        
        ori     x2, x2, 0x10
tmp5:	bgeu 	x3, x4, tmp6        
        ori     x2, x2, 0x20
tmp6:
        # Set up for next pass of conditionals 
 	xor     x2, x2, x2
        addi    x4, x3, 8
        beq	x3, x4, tmp11
        ori     x2, x2, 0x01
tmp11:	bne	x3, x4, tmp12
        ori     x2, x2, 0x02
tmp12:	blt	x3, x4, tmp13
        ori     x2, x2, 0x04
tmp13:	bge	x3, x4, tmp14
        ori     x2, x2, 0x08
tmp14: bltu	x3, x4, tmp15
        ori     x2, x2, 0x10 
tmp15: bgeu	x3, x4, tmp16
        ori     x2, x2, 0x20 
tmp16:
xor	x2, x2, x2
xor x3, x3, x3
xor x4, x4, x4
addi x3, x0, 1
       # addi    x4, x2, 0xFFFFFFE0
	beq	x3, x4, tmp21
        ori     x2, x2, 0x01
tmp21:	bne	x3, x4, tmp22
        ori     x2, x2, 0x02
tmp22:	blt	x3, x4, tmp23
        ori     x2, x2, 0x04
tmp23:	bge	x3, x4, tmp24
        ori     x2, x2, 0x08
        addi x0, x0, 36
        addi x0, x0, 36
tmp24:	bltu	x0, x3, tmp25
        ori     x2, x2, 0x10
tmp25:	bgeu	x3, x4,	tmp26
        ori     x2, x2, 0x20
tmp26:
        xor x2, x2, x2
        
        addi x0, x0, 1
        addi x0, x0, 1
        
       
        
         xor x4, x4, x4
         addi x4, x0, 4
         addi x3, x0, 3
         addi x0, x0, 4
         addi x0,x0, 25
        tmp27:	bltu	x4, x3, tmp29
        tmp29:	bltu	x3, x4, tmp28
        ori     x2, x2, 0x10
         ori     x2, x2, 0x10
          addi     x2, x2, 0x10
        
        tmp28:	bltu	x3, x4, tmp30
        addi     x2, x2, 0x10
        tmp30:	bltu	x3, x4, tmp31
        addi     x3, x4, 0x10
        tmp31:  lbu x4, 0(x7)
        addi x3, x4, 0x10
        
        addi x3, x0, 1
        add x1, x0, 0
       addi x6, x6, 1
        addi x6, x6, 1
        bltu	x3, x4, tmp32
        ori     x2, x2, 0x10
         ori     x2, x2, 0x10
          addi     x2, x2, 0x10
        tmp32:    ori     x2, x2, 0x10
         ori     x2, x2, 0x10
          addi     x2, x2, 0x10
          
        tmp33: addi x21, x21, 1  
        sub x0, x0, x6
        addi x0, x0, 3
        addi x0, x0, 3
        xor x1, x1, x1
        xor x1, x1, x1
        addi x1, x1, 1
        addi x1, x1, 1
        addi x2, x2, 4
        addi x2, x2, 4
        xor x1, x1, x1
        lbu  x2, 3(x7)
        lb  x2, 2(x7)
        lw  x1, 0(x7)
       
        lbu x2, 0(x7)
        add x2, x2, x2
        xor x1, x1, x1
          bltu  x2,x2, tmp34
          
          xor x1, x1, x1
          add x1, x2, 35
         addi     x23, x2, 0x10
          sub x1, x1, x1
          tmp34:   bltu  x2,x1, tmp35
          add x26, x2, x1
                  add x26, x2, x1
                  
                  tmp35: add x17, x17, x1
                  add x17, x17, x1
          
        

    # Add your own test cases here!

    slti x0, x0, -256 # this is the magic instruction to end the simulation
