#define ICW1_ICW4 0x01
#define ICW1_SINGLE 0x02
#define ICW1_INTERVAL4 0x04
#define ICW1_LEVEL 0x08
#define ICW1_INIT 0x10

#define ICW4_8086 0x01
#define ICW4_AUTO 0x02
#define ICW4_BUF_SLAVE 0x04
#define ICW4_BUF_MASTER 0x08
#define ICW4_SFNM 0x10

#define PIC_READ_IRR 0x0A
#define PIC_READ_ISR 0x0B

enum PIC_PORTS {
	PIC1_COMMAND = 0x20,
	PIC1_DATA = 0x21,
	PIC2_COMMAND = 0xA0,
	PIC2_DATA = 0xA1
};

enum PIC_COMMANDS {
	EOI = 0x20
};

struct IDT_Descriptor {
	unsigned int baseLow : 16;
	unsigned int selector : 16;
	unsigned int zero : 8;
	unsigned int flags : 8;
	unsigned int baseHigh : 16;
} __attribute__ ((__packed__));

struct IDT_Pointer {
	unsigned int end : 16;
	unsigned int start : 32;
} __attribute__ ((__packed__));

void initialise_PICs (uint8_t offset1, uint8_t offset2) {
	uint8_t a1, a2;

	// Save interrupt masks
	a1 = inb(PIC1_DATA);
	a2 = inb(PIC2_DATA);

	// Start initialisation sequence
	outb(PIC1_COMMAND, ICW1_INIT+ICW1_ICW4);
	outb(PIC2_COMMAND, ICW1_INIT+ICW1_ICW4);

	// Set vector offsets
	outb(PIC1_DATA, offset1);
	outb(PIC2_DATA, offset2);

	// Set cascades and stuff
	outb(PIC1_DATA, 4);
	outb(PIC2_DATA, 2);

	// Set 8086 mode, not sure what this actually does
	outb(PIC1_DATA, ICW4_8086);
	outb(PIC2_DATA, ICW4_8086);

	// Restore masks
	outb(PIC1_DATA, a1);
	outb(PIC2_DATA, a2);
}

void send_PIC_EOI (uint8_t irq) {
	if (irq >= 8) {
		outb(PIC2_COMMAND, EOI);
	}
	outb(PIC1_COMMAND, EOI);
}

// Enable an IRQ by setting it's mask bit to 1
void enable_PIC_IRQ (uint8_t irq) {
	uint16_t port;
	uint8_t data;

	if(irq < 8) {
		port = PIC1_DATA;
	} else {
		port = PIC2_DATA;
		irq -= 8;
	}

	data = inb(port) & ~(1 << irq);
	outb(port, data);
}

// Disable an IRQ by setting it's mask bit to 0
void disable_PIC_IRQ (uint8_t irq) {
	uint16_t port;
	uint8_t data;

	if(irq < 8) {
		port = PIC1_DATA;
	} else {
		port = PIC2_DATA;
		irq -= 8;
	}

	data = inb(port) | (1 << irq);
	outb(port, data);
}

static uint16_t get_IRQ_reg (uint8_t ocw3) {
	outb(PIC1_COMMAND, ocw3);
	outb(PIC2_COMMAND, ocw3);
	return (inb(PIC2_COMMAND)<< 8 | inb(PIC1_COMMAND));
}

uint16_t get_PIC_IRR () {
	return get_IRQ_reg(PIC_READ_IRR);
}

uint16_t get_PIC_ISR () {
	return get_IRQ_reg(PIC_READ_ISR);
}

uint32_t setup_IDT (uint32_t *ISRs) {
	// Disable interupts
	asm volatile ("cli\n\t");

	// Create a descriptor
	struct IDT_Descriptor descriptor[256];

	for (int i = 0; i < 256; i++)	{
		// Set ISR address
		descriptor[i].baseLow = (uint16_t)(ISRs[i] & 0x0000FFFF);
		descriptor[i].baseHigh = (uint16_t)((ISRs[i] >> 16) & 0x0000FFFF);

		// Set the selector to our code segment
		descriptor[i].selector = 0x08;

		// Set the reserved byte to zero
		descriptor[i].zero = 0;

		// Set flags for 32-bit, Ring 0
		descriptor[i].flags = 0b010001110;
	}

	// Create IDT pointer
	struct IDT_Pointer pointer;
	pointer.start = &descriptor;
	pointer.end = (256*8)-1;

	uint32_t idt_pointer_address = &pointer;

	asm volatile ("lidt (%0); sti" :: "r"(idt_pointer_address));

	return idt_pointer_address;
}