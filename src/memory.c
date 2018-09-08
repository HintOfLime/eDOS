#include "stdint.h"
#include "memory.h"
#include "video.h"
#include "utility.h"

struct Map_Entry {
    uint64_t BASE : 64;
    uint64_t SIZE : 64;
    uint32_t TYPE : 32;
    uint32_t ACPI : 32;
} __attribute__ ((__packed__));

enum MEMORY_TYPE {
    USABLE = 1,
    RESERVED = 2,
    ACPI_RECLAIMABLE = 3,
    ACPI_NVS = 4,
    BAD = 5
};

const uint32_t MAP_LOCATION = 0x8000;

void get_memory_map () {
    uint32_t map_size = *((uint8_t*)(MAP_LOCATION - 4));
    struct Map_Entry* map = (uint8_t*)MAP_LOCATION;
    //put_string((char*)0xb8000, int_to_hex_string(map_size), 0x07);
    //put_string((char*)0xb8000, " memory map entries\n\r", 0x07);

    // 64 bits should be enough for the foreseeable future
    // Although we only display it to 32 bits for now
    uint64_t total = 0;

    put_string((char*)0xb8000, "+----------+----------+----------+----------+\n\r", 0x07);
    put_string((char*)0xb8000, "|   Base   |   Size   |   Type   |   ACPI   |\n\r", 0x07);
    put_string((char*)0xb8000, "+----------+----------+----------+----------+\n\r", 0x07);
    for (int i = 0; i < map_size; i++) {
        put_string((char*)0xb8000, "| ", 0x07);
        put_string((char*)0xb8000, int_to_hex_string((uint32_t)map[i].BASE), 0x07);
        put_string((char*)0xb8000, " | ", 0x07);
        put_string((char*)0xb8000, int_to_hex_string((uint32_t)map[i].SIZE), 0x07);
        put_string((char*)0xb8000, " | ", 0x07);
        put_string((char*)0xb8000, int_to_hex_string(map[i].TYPE), 0x07);
        put_string((char*)0xb8000, " | ", 0x07);
        put_string((char*)0xb8000, int_to_hex_string(map[i].ACPI), 0x07);
        put_string((char*)0xb8000, " |\n\r", 0x07);

        if ((map[i].TYPE == USABLE) && ((map[i].ACPI & 1) == 1)  && ((map[i].ACPI & 2) == 0)) {
            total += map[i].SIZE;
        }
    }
    put_string((char*)0xb8000, "+----------+----------+----------+----------+\n\r", 0x07);

    // Print total memory in appropriate units
    if (total > (1024*1024)) {
        put_string((char*)0xb8000, int_to_string(((total/1024)/1024)), 0x07);
        put_string((char*)0xb8000, "Mb usable memory detected\n\r", 0x07);
    }
    else if (total > 1024) {
        put_string((char*)0xb8000, int_to_string((total/1024)), 0x07);
        put_string((char*)0xb8000, "Kb usable memory detected\n\r", 0x07);
    }
    else {
        // Worst case
        put_string((char*)0xb8000, int_to_string((total)), 0x07);
        put_string((char*)0xb8000, "b usable memory detected\n\r", 0x07);
    }
}