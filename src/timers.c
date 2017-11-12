#include "ports.c"

// Set IRQ0 to fire at rate of once per the specifed time period
void set_timer (uint16_t milliseconds) {
	uint16_t count = milliseconds / 1000; // 1000Hz -> 1ms

	// Set PIC mode
	// Binary Counting, Mode 3, LSB then MSB, Channel 0
	outb(0x43, 54);

	// Set count
	uint8_t msb = (count >> 8) & 0x0F;
	outb(0x40, msb);
	uint8_t lsb = count & 0x0F;
	outb(0x40, lsb);
}

void init_timer () {

}