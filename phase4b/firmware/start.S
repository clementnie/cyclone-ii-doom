.section .init,"ax"
.global _start
_start:
    la sp, __stack_top
    la t0, __data_load
    la t1, __data_start
    la t2, __data_end
1:  bgeu t1, t2, 2f
    lbu t3, 0(t0)
    sb t3, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    j 1b
2:  la t1, __bss_start
    la t2, __bss_end
3:  bgeu t1, t2, 4f
    sb zero, 0(t1)
    addi t1, t1, 1
    j 3b
4:  call main
    ebreak
5:  j 5b
