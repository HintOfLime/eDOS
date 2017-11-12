#define ICW1_ICW4 0x01
#define ICW1_SINGLE 0x02
#define ICW1_INTERVAL4 0x04
#define ICW1_LEVEL 0x08
#define ICW1_INIT 0x10

#define ICW4_8086 0x01
#define ICW4_AUTO 0x02
#define ICW4_BUF_SLAVE 0x04
#define ICW4_BUF_MASTER 0x08
#define  ICW4_SFNM 0x10

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
	uint16_t baseLow : 16;
	uint16_t selector : 16;
	uint8_t reserved : 8;
	uint8_t flags : 8;
	uint16_t baseHigh : 16;
};

struct IDT_Pointer {
	uint16_t end : 16;
	uint32_t start : 32;
};

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

void setup_IDT (uint32_t *ISRs) {
	// Disable interupts
	asm volatile ("cli\n\t");

	// Create a descriptor
	struct IDT_Descriptor descriptor[2];

	for (int i = 0; i < sizeof(ISRs)/4; i++)	{
		// Set ISR address
		descriptor[i].baseLow = ISRs[i] & 0x0000FFFF;
		descriptor[i].baseHigh = (ISRs[i] >> 16) & 0x0000FFFF;

		// Set the selector to our code segment
		descriptor[i].selector = 0x8;

		// Set flags for 32-bit, Ring 0
		descriptor[i].flags = 0b010001110;
	}

	// Create IDT pointer
	struct IDT_Pointer pointer;
	pointer.start = &descriptor;
	pointer.end = (sizeof(ISRs)/4)*8;

	uint32_t pointer_pointer = &pointer;

	asm volatile ("mov %%ebx, %0\n\tlidt (%%ebx)\n\tsti\n\t" : : "r"(pointer_pointer) : "%ebx");
}