.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.
 lui     x7, 0x12345
xor x2, x1, x3
addi x2, x2, 0x123
add  x4, x7, x2
xor x4, x7, x2
addi x7, x1, 0x456
  
    xor	x1, x1, x1
	xor	x2, x2, x2
        # Set x1 to one
	addi	x1, x1, 1 
        # Test resgister+register adds.
	add 	x2, x1, x1
	add 	x2, x2, x1
	add 	x2, x1, x2

    # test LUI
    lui     x2, 0xABCDE
    
 addi x8, x0, 0x100  # x1 <= 4
    addi x1, x0, 100  # x1 <= 4
    nop
    nop
    nop             # nops in between to prevent hazard
    nop
    nop
    addi x3, x1, 123  # x3 <= x1 + 8
    addi x2, x0, 44
    addi x4, x0, 55
    addi x5, x0, 22
    addi x6, x0, 90
    addi x7, x0, 81
    addi x8, x0, 92
    addi x9, x0, 37
     srai 	x1,x1,16
    srli 	x2,x2,23
    slli 	x3,x3,13
    xori 	x5, x4, 0x666
    ori 	x5, x4, 0x666
    andi 	x5, x4, 0x666
    slti  x5, x4, 0x666
    sltiu x5, x4, 0x666
    add x5, x4, x3
    sub x5, x4, x3
    sll x5, x4, x3
    xor x5, x4, x3
    srl x5, x4, x3
    sra x5, x4, x3
    or x5, x4, x3
    and x5, x4, x3
    slt x5, x4, x3
     add x5, x4, x3
    sub x5, x4, x3
    sll x5, x4, x3
    xor x5, x4, x3
    srl x5, x4, x3
    sra x5, x4, x3
    or x5, x4, x3
    and x5, x4, x3
     slt x5, x4, x3
    sltu x5, x4, x3
    lui     x2, 0xFFFFF
    AUIPC   x2, 0x12345
    xori 	x5, x4, 0x666
    ori 	x5, x4, 0x666
    andi 	x5, x4, 0x666
    slti  x5, x4, 0x666
    sltiu x5, x4, 0x666
    add x5, x4, x3
    sub x5, x4, x3
    sll x5, x4, x3
    xor x5, x4, x3
    srl x5, x4, x3
    sra x5, x4, x3
    or x5, x4, x3
    and x5, x4, x3
    slt x5, x4, x3
     add x5, x4, x3
    sub x5, x4, x3
    sll x5, x4, x3
    xor x5, x4, x3
    srl x5, x4, x3
    sra x5, x4, x3
    or x5, x4, x3
    and x5, x4, x3
    slt x5, x4, x3
    sltu x5, x4, x3
    lui     x2, 0xFFFFF
    AUIPC   x2, 0x12345
    addi x3, x1, 123  # x3 <= x1 + 8
    addi x2, x0, 44
    addi x4, x0, 55
    addi x5, x0, 22
    addi x6, x0, 90
    addi x7, x0, 81
    addi x8, x0, 92
    addi x9, x0, 37
    srai 	x1,x1,16
    srli 	x2,x2,23
    slli 	x3,x3,13
    xori 	x5, x4, 0x666
    ori 	x5, x4, 0x666
    andi 	x5, x4, 0x666
    slti  x5, x4, 0x666
    sltiu x5, x4, 0x666
    add x5, x4, x3
    sub x5, x4, x3
    sll x5, x4, x3

	
        




    # Add your own test cases here!

    slti x0, x0, -256 # this is the magic instruction to end the simulation
