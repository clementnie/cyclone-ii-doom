OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
 ROM (rx) : ORIGIN = 0, LENGTH = 8K
 RAM (rw) : ORIGIN = 0x10000, LENGTH = 8K
 SDRAM (rw) : ORIGIN = 0x20020000, LENGTH = 0x7e0000
}
SECTIONS {
 .text : { KEEP(*(.init)) *(.text*) *(.rodata*) } > ROM
 .data : { __data_start = .; *(.sdata*) *(.data*) __data_end = .; } > RAM AT> ROM
 __data_load = LOADADDR(.data);
 .bss (NOLOAD) : { __bss_start = .; *(.bss*) *(.sbss*) *(COMMON) __bss_end = .; } > SDRAM
 __stack_top = ORIGIN(RAM) + LENGTH(RAM);
 /DISCARD/ : { *(.comment) *(.eh_frame*) *(.riscv.attributes) }
}
