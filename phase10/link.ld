OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { SDRAM (rwx) : ORIGIN = 0x20020000, LENGTH = 0x7e0000 }
SECTIONS {
 .text : { KEEP(*(.init)) *(.text*) *(.rodata*) } > SDRAM
 .data : { __data_start = .; *(.sdata*) *(.data*) __data_end = .; } > SDRAM
 __data_load = LOADADDR(.data);
 .bss (NOLOAD) : { __bss_start = .; *(.sbss*) *(.bss*) *(COMMON) __bss_end = .; } > SDRAM
 . = ALIGN(16);
 __heap_start = .;
 __stack_top = ORIGIN(SDRAM) + LENGTH(SDRAM);
 __wad_base = 0x20380000;
 __wad_limit = __stack_top - 64K;
 __heap_end = __wad_base;
 ASSERT(__heap_start < __heap_end, "Engine overlaps reserved WAD region")
 /DISCARD/ : { *(.comment) *(.eh_frame*) }
}
