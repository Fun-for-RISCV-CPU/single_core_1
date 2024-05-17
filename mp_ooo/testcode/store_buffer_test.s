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

