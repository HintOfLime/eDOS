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

static uint32_t *irq_handlers[255] = {};

void default_IRQ_handler () {
	asm("cli; pusha; xchgw %bx, %bx");
	put_string((char*)0xb8000, "Unknown IRQ triggered!\n\r", 0x07);
	asm("popa; leave; sti; iret");
}

static int timerCount = 0;

void PIT_handler () {
	asm("cli; pusha; xchgw %bx, %bx");
	//put_string((char*)0xb8000, "PIT interrupt triggered!\n\r", 0x07);

	timerCount += 1;
	if (timerCount > 20) {
		put_string((char*)0xb8000, "~1 second has passed!\n\r", 0x07);
		timerCount = 0;
	}

	uint8_t msb = (timerReloadValue >> 8) & 0x0F;
	outb(0x40, msb);
	uint8_t lsb = timerReloadValue & 0x0F;
	outb(0x40, lsb);

	send_PIC_EOI(0);
	asm("popa; leave; sti; iret");
}

void keyboard_handler () {
	asm("cli; pusha; xchgw %bx, %bx");
	inb(0x60);
	put_string((char*)0xb8000, "Keyboard interrupt triggered!\n\r", 0x07);
	send_PIC_EOI(1);
	asm("popa; leave; sti; iret");
}

char* int_to_string (uint8_t in) {
	char *out = "   ";
	out[0] = (in / 100) + 48;
	out[1] = ((in % 100) / 10) + 48;
	out[2] = ((in % 100) % 10) + 48;
	out[3] = '\0';

	return out;
}

char* int_to_hex_string (uint32_t in) {
	char *out = "        ";

	out[7] = in & 0x000F;
	out[6] = (in >> 4) & 0x000F;
	out[5] = (in >> 8) & 0x000F;
	out[4] = (in >> 12) & 0x000F;
	out[3] = (in >> 16) & 0x000F;
	out[2] = (in >> 20) & 0x000F;
	out[1] = (in >> 24) & 0x000F;
	out[0] = (in >> 28) & 0x000F;

	out[8] = '\0';

	for (int i = 0; i < 8; i++) {
		if (out[i] > 9) {
			out[i] += 55;
		}
		else {
			out[i] += 48;
		}
	}

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

	// Disable all PIC interrupts except Keyboard and PIT
	for (int i = 0; i < 16; i++) {
		if (i == 0 | i == 1) {
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

	// Set ISRs
	for (int i = 0; i < 256; i++) {
		irq_handlers[i] = &default_IRQ_handler;
	}
	irq_handlers[0x20] = &PIT_handler;
	irq_handlers[0x21] = &keyboard_handler;

	// Setup our IDT
	uint32_t idt_pointer_address = setup_IDT(irq_handlers);;
	put_string(vidptr, "IDT loaded (Pointer address: ", 0x07);
	put_string(vidptr, int_to_hex_string(idt_pointer_address), 0x07);
	put_string(vidptr, ")\n\r", 0x07);

	// Set a timer for 0.05 seconds
	set_timer(50);
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