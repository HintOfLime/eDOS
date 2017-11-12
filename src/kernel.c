// I know this is nasty but we have to have the code we want to execute at the begining of the file
void kernel_entry () {
	kernel_main();
}

#include "stdint.h"
#include "video.c"
#include "FAT12.c"
#include "timers.c"
#include "interrupts.c"

void halt () {
	//asm("cli; hlt;");
	asm ("hlt");
}

void IRQ0_Handler () {
	asm("pusha");
	put_string((char*)0xb8000, "IRQ0 triggered!\n\r", 0x07);
	send_PIC_EOI(0);
	asm("popa; leave; iret");
}

void IRQ1_Handler () {
	asm("pusha");
	put_string((char*)0xb8000, "IRQ1 triggered!\n\r", 0x07);
	send_PIC_EOI(1);
	asm("popa; leave; iret");
}

char* int_to_string (uint8_t in) {
	char *out = "   ";
	out[0] = (in / 100) + 48;
	out[1] = ((in % 100) / 10) + 48;
	out[2] = ((in % 100) % 10) + 48;

	return out;
}

void kernel_main () {
	// Setup pointer into VGA memory
	const char *vidptr = (char*)0xb8000;	
	
	// Clear screen and write status message
	fill_screen(vidptr, ' ', 0x07);
	put_string(vidptr, "Kernel started\n\r", 0x07);

	// Remap PIC IRQs to unused lines
	initialise_PICs(0x20, 0x28);
	put_string(vidptr, "PICs remapped\n\r", 0x07);

	// Disable all interrupts except Keyboard
	for (int i = 0; i < 16; i++) {
		if (i == 1) {
			enable_PIC_IRQ(i);
			put_string(vidptr, "Enabled  IRQ", 0x07);
			put_string(vidptr, int_to_string(i), 0x07);
			put_string(vidptr, "\n\r", 0x07);
		}
		else {
			disable_PIC_IRQ(i);
			put_string(vidptr, "Disabled IRQ", 0x07);
			put_string(vidptr, int_to_string(i), 0x07);
			put_string(vidptr, "\n\r", 0x07);
		}
	}

	// Setup our IDT
	uint32_t *irq_handlers[2] = {&IRQ0_Handler, &IRQ1_Handler};
	setup_IDT(irq_handlers);
	put_string(vidptr, "IDT loaded\n\r", 0x07);

	// Set a timer for one second
	set_timer(1000);
	put_string(vidptr, "PIT started\n\r", 0x07);


	// Try to load a file
	uint8_t val = load_file("TEST    TXT", 0, 0x400000); 
	if (val) {
		put_string(vidptr, "Disk error!\n\r", 0x07);
	}

	while (1) {
		halt();
	}
}