#include "stdint.h"
#include "keyboard.h"
#include "ports.h"
#include "interrupts.h"
#include "video.h"
#include "utility.h"

enum SCANCODES {
   	NULL_KEY = 0,
	Q_PRESSED = 0x10,
	Q_RELEASED = 0x90,
	W_PRESSED = 0x11,
	W_RELEASED = 0x91,
	E_PRESSED = 0x12,
	E_RELEASED = 0x92,
	R_PRESSED = 0x13,
	R_RELEASED = 0x93,
	T_PRESSED = 0x14,
	T_RELEASED = 0x94,
	Y_PRESSED = 0x15,
	Y_RELEASED = 0x95,
	U_PRESSED = 0x16,
	U_RELEASED = 0x96,
	I_PRESSED = 0x17,
	I_RELEASED = 0x97,
	O_PRESSED = 0x18,
	O_RELEASED = 0x98,
	P_PRESSED = 0x19,
	P_RELEASED = 0x99,
	A_PRESSED = 0x1E,
	A_RELEASED = 0x9E,
	S_PRESSED = 0x1F,
	S_RELEASED = 0x9F,
	D_PRESSED = 0x20,
	D_RELEASED = 0xA0,
	F_PRESSED = 0x21,
	F_RELEASED = 0xA1,
	G_PRESSED = 0x22,
	G_RELEASED = 0xA2,
	H_PRESSED = 0x23,
	H_RELEASED = 0xA3,
	J_PRESSED = 0x24,
	J_RELEASED = 0xA4,
	K_PRESSED = 0x25,
	K_RELEASED = 0xA5,
	L_PRESSED = 0x26,
	L_RELEASED = 0xA6,
	Z_PRESSED = 0x2C,
	Z_RELEASED = 0xAC,
	X_PRESSED = 0x2D,
	X_RELEASED = 0xAD,
	C_PRESSED = 0x2E,
	C_RELEASED = 0xAE,
	V_PRESSED = 0x2F,
	V_RELEASED = 0xAF,
	B_PRESSED = 0x30,
	B_RELEASED = 0xB0,
	N_PRESSED = 0x31,
	N_RELEASED = 0xB1,
	M_PRESSED = 0x32,
	M_RELEASED = 0xB2,

	ZERO_PRESSED = 0x29,
	ONE_PRESSED = 0x2,
	NINE_PRESSED = 0xA,

	POINT_PRESSED = 0x34,
	POINT_RELEASED = 0xB4,

	BACKSPACE_PRESSED = 0xE,
	BACKSPACE_RELEASED = 0x8E,
	SPACE_PRESSED = 0x39,
	SPACE_RELEASED = 0xB9,
	ENTER_PRESSED = 0x1C,
    ENTER_RELEASED = 0x9C,

    CAPSLOCK_PRESSED = 0x3A
};

void keyboard_handler () {
	asm("cli; pusha; xchgw %bx, %bx");
	uint8_t scancode = inb(0x60);
    char key = scancode_to_ascii(scancode);
	//put_string((char*)0xb8000, "Scan code ", 0x07);
    //put_string((char*)0xb8000, int_to_hex_string(scancode), 0x07);
    //put_string((char*)0xb8000, " receieved\n\r", 0x07);
    if (key != 0) {
        put_char((char*)0xb8000, key, 0x07);
        //put_string((char*)0xb8000, " key pressed\n\r", 0x07);
    }
	send_PIC_EOI(1);
	asm("popa; leave; sti; iret");
}

const char* map_qwertyuiop = "qwertyuiop";
const char* map_asdfghjkl = "asdfghjkl";
const char* map_zxcvbnm = "zxcvbnm";
const char* map_0123456789 = "123456789";

static uint8_t caps = 0;

char scancode_to_ascii (uint8_t scancode) {
    if (scancode >= Q_PRESSED && scancode <= P_PRESSED) {
        return map_qwertyuiop[scancode - Q_PRESSED] - (32*caps);
    }
    else if (scancode >= A_PRESSED && scancode <= L_PRESSED) {
        return map_asdfghjkl[scancode - A_PRESSED] - (32*caps);
    }
    else if (scancode >= Z_PRESSED && scancode <= M_PRESSED) {
        return map_zxcvbnm[scancode - Z_PRESSED] - (32*caps);
    }
    else if (scancode >= ONE_PRESSED && scancode <= NINE_PRESSED) {
        return map_0123456789[scancode - ONE_PRESSED];
    }
    else if (scancode == ZERO_PRESSED) {
        return '0';
    }
    else if (scancode == SPACE_PRESSED) {
        return ' ';
    }
    else if (scancode == ENTER_PRESSED) {
        return '\n';
    }
    else if (scancode == CAPSLOCK_PRESSED) {
        caps = (caps ^ 0x01);
    }
    return 0;
}