// I know this is nasty but we have to have the code we want to execute at the begining of the file
void kernel_entry () {
	asm("cli");
	kernel_main();
}

#include "stdint.h"
#include "video.h"
#include "utility.h"
#include "ports.h"
#include "interrupts.h"
#include "timers.h"
#include "keyboard.h"

void default_IRQ_handler () {
	asm("cli; pusha; xchgw %bx, %bx");
	put_string((char*)0xb8000, "Unknown IRQ triggered!\n\r", 0x07);
	halt();
	asm("popa; leave; sti; iret");
}

static int timerCount = 0;
static int secondsPassed = 0;

void timerFunc () {
	timerCount += 1;
	if (timerCount >= 50) {
		//put_string((char*)0xb8000, int_to_string(secondsPassed), 0x07);
		//put_string((char*)0xb8000, " seconds have passed!\n\r", 0x07);
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