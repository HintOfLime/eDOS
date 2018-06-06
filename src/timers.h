#ifndef timers
#define timers

void PIT_handler ();
void set_timer (uint16_t frequency, uint32_t address);

#endif