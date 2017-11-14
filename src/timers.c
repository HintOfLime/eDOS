#include "ports.c"

static uint16_t timerReloadValue;

// Set IRQ0 to fire at rate of once per the specifed time period
// Max is 50ms      I don't think this is very accurate
void set_timer (uint16_t milliseconds) {
	// Set PIC mode
	// Binary Counting, Mode 3, LSB then MSB, Channel 0
	outb(0x43, 54);

	// Calculate reload value
	float frequency = 1.0 / (milliseconds/1000.0);
	uint16_t timerReloadValue = (11931820.0 / frequency);

	// Set reload value
	uint8_t msb = (timerReloadValue >> 8) & 0x0F;
	outb(0x40, msb);
	uint8_t lsb = timerReloadValue & 0x0F;
	outb(0x40, lsb);
}