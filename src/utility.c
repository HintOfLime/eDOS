#include "stdint.h"
#include "utility.h"

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