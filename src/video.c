#include "stdint.h"
#include "video.h"
#include "ports.h"

const unsigned int WIDTH =  80;
const unsigned int HEIGHT = 25;

static int vidX = 0;
static int vidY = 0;

void fill_screen (char *vidptr, char c, char a) {
	unsigned int i = 0;
	while (i < WIDTH*HEIGHT*2) {
		vidptr[i] = c;
		vidptr[i+1] = a;
		i += 2;
	}
	
	vidX = 0;
	vidY = 0;
	
	return;
}

void put_char (char *vidptr, char c, char a) {
	switch (c) {
		case '\n': {
			vidX = 0;
			vidY += 1;
			break;
		}
		case '\r': {
			vidX = 0;
			break;
		}
		case '\0': {
			break;
		}
		case '\b': {
			if (vidX > 0) {
				vidX -= 1;
				vidptr[(vidX+(vidY*WIDTH))*2] = 0;
				vidptr[((vidX+(vidY*WIDTH))*2)+1] = a;
			}
			else {
				// Reached start of line, do nothing
				break;
			}
			break;
		}
		default: {
			vidptr[(vidX+(vidY*WIDTH))*2] = c;
			vidptr[((vidX+(vidY*WIDTH))*2)+1] = a;
			vidX += 1;
			break;
		}
	}
	
	if (vidX > WIDTH) {
		vidX = 0;
		vidY += 1;
	}

	if (vidY > HEIGHT-1) {
		scroll_screen(vidptr, 1);
		vidY = HEIGHT-1;
	}

	set_cursor(vidX, vidY);
	return;
}

void put_string (char *vidptr, char *str, char a) {
	unsigned int i = 0;
	while (str[i] != '\0') {
		put_char (vidptr, str[i], a);
		i += 1;
	}
	return;
}

void scroll_screen (char *vidptr, unsigned int rows) {
	unsigned int i = 0;
	unsigned int j = 0;
	while (i < rows) {
		while (j < WIDTH*HEIGHT*2) {
				vidptr[j] = vidptr[j+(WIDTH*2)];
				j += 2;
		}

		j = 0;
		i += 1;
	}
	
	return;
}

void set_cursor (unsigned int x, unsigned int y) {
	uint16_t pos = (y * 80) + x;
 
	outb(0x3D4, 0x0F);
	outb(0x3D5, (uint8_t)(pos & 0xFF));
	outb(0x3D4, 0x0E);
	outb(0x3D5, (uint8_t)((pos >> 8) & 0xFF));
}