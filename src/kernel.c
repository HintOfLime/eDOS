// I know this is nasty but we have to have the code we want to execute at the begining of the file
void kernel_entry () {
	kernel_main();
}

#include "video.c"
#include "FAT12.c"

void halt () {
	__asm__("cli\n\thlt\n\t");
}

void kernel_main () {
	char *vidptr = (char*)0xb8000;
	
	fill_screen(vidptr, ' ', 0x07);
	put_string(vidptr, "Kernel running!\r\n", 0x07);
	
	load_file("TEST    TXT", 0, 0x400000);
	
	halt();
}
