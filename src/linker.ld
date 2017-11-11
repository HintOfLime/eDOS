/* These are the commands I use to compile:															*/
/* i686-elf-gcc -ffreestanding -nostdlib -g -o build/kernel.o -lgcc -T src/linker.ld src/kernel.c	*/
/* objcopy -O binary build/kernel.o build KERNEL.BIN							*/

ENTRY(kernel_entry)

SECTIONS {
	. = 0x100000;
	.text : { *(.text) }

	. = 0x200000;
	.data : { *(.data) }
	.bss : { *(.bss) }
}
