#include "stdint.h"
#include "utility.h"

char* int_to_string (uint32_t in) {
	char *out = "";
	out[0] =  (in / 1000000000) + 48;
	out[1] = ((in / 100000000) % 10) + 48;
	out[2] = ((in / 10000000) % 10) + 48;
	out[3] = ((in / 1000000) % 10) + 48;
	out[4] = ((in / 100000) % 10) + 48;
	out[5] = ((in / 10000) % 10) + 48;
	out[6] = ((in / 1000) % 10) + 48;
	out[7] = ((in / 100) % 10) + 48;
	out[8] = ((in / 10) % 10) + 48;
	out[9] = ((in / 1) % 10) + 48;
	out[10] = '\0';

	return trim_zeroes(out);
}

char* trim_zeroes (char* in) {
	unsigned int l = 0;
	while (in[l] != '\0') {
			l += 1;
	}
	unsigned int i = 0;
	while (in[i] == '0') {
			i += 1;
	}
	for (int j = 0; j < i; j++) {
		if (j+i < l) {
			in[j] = in[j+i];
		}
		else {
			in[j] = 0;
		}
	}

	return in;
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