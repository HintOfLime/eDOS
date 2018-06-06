#ifndef interrupts
#define interrupts


void initialise_PICs (uint8_t offset1, uint8_t offset2);
void send_PIC_EOI (uint8_t irq);
void enable_PIC_IRQ (uint8_t irq);
void disable_PIC_IRQ (uint8_t irq);
uint16_t get_IRQ_reg (uint8_t ocw3);
uint16_t get_PIC_IRR ();
uint16_t get_PIC_ISR ();
void update_IDT ();
void setup_handler(uint8_t interrupt, uint32_t handler_address);
void initialize_IDT (uint32_t default_handler);
void setup_interrupts(uint32_t default_IRQ_handler);

#endif