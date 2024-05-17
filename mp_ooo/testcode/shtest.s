load_store.s:
.align 4
.section .text
.globl _start
    
_start:

    lw  x5, testaddr
    lw  x4, testdata

    # Store x4 to testaddr using sb
    sb x4, 0(x5)    
    srli x4, x4, 8
    sb x4, 1(x5)    
    srli x4, x4, 8
    sb x4, 2(x5)    
    srli x4, x4, 8
    sb x4, 3(x5)  
    srli x4, x4, 8  

    sh x4, 0(x5)
    sh x4, 2(x5)

    sw x4, 0(x5)

    jal x0, tmp0
    nop
    nop
    nop
    nop
    nop

tmp0:    lb x3, 0(x5)
    lb x3, 1(x5)
    lb x3, 2(x5)
    lb x3, 3(x5)

    lbu x3, 0(x5)
    lbu x3, 1(x5)
    lbu x3, 2(x5)
    lbu x3, 3(x5)

    lh x3, 0(x5)
    lh x3, 2(x5)

    lhu x3, 0(x5)
    lhu x3, 2(x5)

    lw x3, 0(x5)

halt:                 
    beq x0, x0, halt  
                      

deadend:
    lw x8, bad     # X8 <= 0xdeadbeef
deadloop:
    beq x8, x8, deadloop

.section .rodata

testslot:   .word 0x00000000
testaddr:   .word testslot
testdata:   .word 0xABCDEF01

bad:        .word 0xdeadbeef
threshold:  .word 0x00000040
result:     .word 0x00000000
good:       .word 0x600d600d

