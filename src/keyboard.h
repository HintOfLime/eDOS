#ifndef keyboard
#define keyboard

void keyboard_handler ();
char scancode_to_ascii (uint8_t scancode);
void setup_keyboard (uint32_t address);

#endif