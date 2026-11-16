OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
 ROM (rx) : ORIGIN = 0x00000000, LENGTH = 8K
 RAM (rw) : ORIGIN = 0x00010000, LENGTH = 8K
}
SECTIONS {
 .text : { KEEP(*(.init)) *(.text*) *(.rodata*) } > ROM
 .data : { __data_start = .; *(.sdata*) *(.data*) __data_end = .; } > RAM AT> ROM
 __data_load = LOADADDR(.data);
 .bss (NOLOAD) : { __bss_start = .; *(.sbss*) *(.bss*) *(COMMON) __bss_end = .; } > RAM
 __stack_top = ORIGIN(RAM) + LENGTH(RAM);
 ASSERT(__bss_end <= __stack_top - 1024, "RAM must leave 1 KiB stack")
 ASSERT(LOADADDR(.data) + SIZEOF(.data) <= ORIGIN(ROM) + LENGTH(ROM), "ROM overflow")
 /DISCARD/ : { *(.comment) *(.eh_frame*) *(.riscv.attributes) }
}
