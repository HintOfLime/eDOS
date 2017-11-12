#include "disk.c"

uint8_t load_file (char *filename, unsigned int disk, unsigned int address) {
	return read_sectors(1, 1, disk, 0x300000); // Read sector 1 to 3Mib
}