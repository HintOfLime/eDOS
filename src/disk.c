#include "ports.c"

const unsigned int SECTORS_PER_TRACK = 18;

struct chs {
	unsigned int c;
	unsigned int h;
	unsigned int s;
};

enum floppy_registers {
	STATUS_REGISTER_A = 0x3F0,
	STATUS_REGISTER_B = 0x3F1,
	DIGITAL_OUTPUT_REGISTER = 0x3F2,
	TAPE_DRIVE_REGISTER = 0x3F3,
	MAIN_STATUS_REGISTER = 0x3F4,
	DATARATE_SELECT_REGISTER = 0x3F4,
	DATA_FIFO = 0x3F5,
	DIGITAL_INPUT_REGISTER = 0x3F7,
	CONFIGURATION_CONTROL_REGISTER = 0x3F7
};

enum floppy_commands {
	READ_TRACK = 2,
	SPECIFY = 3,
	SENSE_DRIVE_STATUS = 4,
	WRITE_DATA = 5,
	READ_DATA = 6,
	RECALIBRATE = 7,
	SENSE_INTERRUPT = 8,
	WRITE_DELETED_DATA = 9,
	READ_ID = 10,
	READ_DELETED_DATA = 12,
	FORMAT_TRACK = 13,
	SEEK = 15,
	VERSION = 16,
	SCAN_EQUAL = 17,
	PERPENDICULAR_MODE = 18,
	CONFIGURE = 19,
	LOCK = 20,
	VERIFY = 22,
	SCAN_LOW_OR_EQUAL = 25,
	SCAN_HIGH_OR_EQUAL = 29
};

struct chs lba_chs (unsigned int lba) {
	struct chs out;
	out.c = lba / (2 * SECTORS_PER_TRACK);
	out.h = ((lba % (2 * SECTORS_PER_TRACK)) / SECTORS_PER_TRACK);
	out.s = ((lba % (2 * SECTORS_PER_TRACK)) % SECTORS_PER_TRACK + 1);
	return out;
}

void reset_floppy () {
	// Reset floppy controller
}

uint8_t floppy_command (uint8_t command, uint8_t parameters[]) {
	if (inb(MAIN_STATUS_REGISTER) & 0xC0 != 0x80) {
		// Controller not ready, reset
		reset_floppy();
	}

	// Send command
	outb(DATA_FIFO, command);
	while (inb(MAIN_STATUS_REGISTER) & 0xC0 != 0x80) {
		// Wait for controller to be ready
	}

	// Send parameters
	for (unsigned int i = 0; i < sizeof(parameters); i++) {
		outb(DATA_FIFO, parameters[i]);
		while (inb(MAIN_STATUS_REGISTER) & 0xC0 != 0x80) {
			// Wait for controller to be ready
		}
	}

	return 0;
}

void initialise_disk (unsigned int disk) {
	return;
}

uint8_t read_sectors (unsigned int start_sector, unsigned int sectors, unsigned int disk, unsigned int memory_location) {
	// Check disk type
	outb(0x70, (1 << 7) | (0x10));
	uint8_t diskType = (inb(0x71) >> 4) & 0x0F;
	if (diskType != 4){
		return 1;
	}

	initialise_disk(disk);

	// Convert LBA to CHS
	struct chs location;
	location = lba_chs(start_sector);

	return 0;
}