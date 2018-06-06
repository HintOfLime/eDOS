#include "stdint.h"
#include "timers.h"

#include "ports.h"
#include "interrupts.h"
#include "video.h"

void (*callbackAddress)(void);

void PIT_handler () {
	asm("cli; pusha; xchgw %bx, %bx");

	(callbackAddress)();
	send_PIC_EOI(0);

	asm("popa; leave; sti; iret");
}

// Set IRQ0 to fire at rate of once per the specifed time period
// Max is 50ms		I don't think this is very accurate
void set_timer (uint16_t frequency, uint32_t address) {
	callbackAddress = address;
	setup_handler(0x20, (uint32_t)&PIT_handler);
	update_IDT();
	enable_PIC_IRQ(0);

	// Set PIC mode
	// Binary Counting, Mode 3, LSB then MSB, Channel 0
	outb(0x43, 0x36);

	// Calculate reload value
	uint16_t timerReloadValue = 1193180 / frequency;

	// Set reload value
	uint8_t lsb = timerReloadValue & 0x00FF;
	outb(0x40, lsb);
	uint8_t msb = (timerReloadValue >> 8) & 0x00FF;
	outb(0x40, msb);
}