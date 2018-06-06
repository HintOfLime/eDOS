// I know this is nasty but we have to have the code we want to execute at the begining of the file
void kernel_entry () {
	asm("cli");
	kernel_main();
}

#include "stdint.h"
#include "video.h"
#include "ports.h"
#include "interrupts.h"
#include "timers.h"

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

void halt () {
	asm("cli; hlt;");
}

void wait() {
	asm ("hlt");
}

void default_IRQ_handler () {
	asm("cli; pusha; xchgw %bx, %bx");
	put_string((char*)0xb8000, "Unknown IRQ triggered!\n\r", 0x07);
	halt();
	asm("popa; leave; sti; iret");
}

void keyboard_handler () {
	asm("cli; pusha; xchgw %bx, %bx");
	inb(0x60);
	put_string((char*)0xb8000, "Keyboard interrupt triggered!\n\r", 0x07);
	send_PIC_EOI(1);
	asm("popa; leave; sti; iret");
}

static int timerCount = 0;
static int secondsPassed = 0;

void timerFunc () {
	timerCount += 1;
	if (timerCount >= 50*1000) {
		put_string((char*)0xb8000, int_to_string(secondsPassed), 0x07);
		put_string((char*)0xb8000, " seconds have passed!\n\r", 0x07);
		secondsPassed += 1;
		timerCount = 0;
	}
}

void kernel_main () {
	// Clear screen and write status message
	fill_screen((char*)0xb8000, ' ', 0x07);
	put_string((char*)0xb8000, "Kernel started\n\r", 0x07);

	// Setup interupts with default handler
	setup_interrupts((uint32_t)&default_IRQ_handler);

	// Setup keyboard handler
	setup_handler(0x21, (uint32_t)&keyboard_handler);
	update_IDT();
	enable_PIC_IRQ(1);

	// Set a timer for 50Hz
	set_timer(50, &timerFunc);
	put_string((char*)0xb8000, "PIT started\n\r", 0x07);

	while (1) {
		wait();
	}
}