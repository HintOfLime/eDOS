#include "video.h"

const unsigned int WIDTH =  80;
const unsigned int HEIGHT = 25;

static unsigned int vidX = 0;
static unsigned int vidY = 0;

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

void put_string (char *vidptr, char *str, char a) {
	unsigned int i = 0;
	while (str[i] != '\0') {
		switch (str[i]) {
			case '\n': {
				vidY += 1;
				break;
			}
			case '\r': {
				vidX = 0;
				break;
			}
			default: {
				vidptr[(vidX+(vidY*WIDTH))*2] = str[i];
				vidptr[((vidX+(vidY*WIDTH))*2)+1] = a;
				vidX += 1;
				break;
			}
		}
		
		if (vidX > WIDTH) {
			vidX = 0;
			vidY += 1;
		}
		if (vidY > HEIGHT) {
			scroll_screen(vidptr, 1);
			vidY = HEIGHT;
		}
		
		i += 1;
	}
	
	return;
}

void scroll_screen (char *vidptr, unsigned int rows) {
	unsigned int i = 0;
	unsigned int j = 0;
	while (i < rows) {
		while (j < WIDTH*HEIGHT*2) {
			if (j > WIDTH*(HEIGHT-1)*2) {
				vidptr[j] = ' ';
				vidptr[j+1] = 0x07;
				j += 2;
			}
			else {
				vidptr[j] = vidptr[j+(WIDTH*2)];
				j += 2;
			}
		}
		j = 0;
		i += 1;
	}
	
	return;
}
