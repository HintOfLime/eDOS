// Currently have to have entry point at beggining of file because the bootloader only works with flat binaries
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
#include "memory.h"

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
		//puvoid setup_keyboard (uint32_t address)t_string((char*)0xb8000, " seconds have passed!\n\r", 0x07);
		secondsPassed += 1;
		timerCount = 0;
	}
}

void keypressFunc (char key) {
	// Print characters to screen as they are typed
	put_char((char*)0xb8000, key, 0x07);
}

void kernel_main () {
	// Clear screen and write status message
	fill_screen((char*)0xb8000, ' ', 0x07);
	put_string((char*)0xb8000, "Kernel started\n\r", 0x07);

	// Setup interupts with default handler
	setup_interrupts((uint32_t)&default_IRQ_handler);

	// Setup keyboard
	setup_keyboard(&keypressFunc);

	// Set a timer for 50Hz
	setup_timer(50, &timerFunc);
	put_string((char*)0xb8000, "PIT started\n\r", 0x07);

	get_memory_map();

	// Do nothing
	while (1) {
		wait();
	}
}