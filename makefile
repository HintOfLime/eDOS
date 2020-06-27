.DEFAULT_GOAL := all

CC = i686-elf-gcc
LD = i686-elf-ld

CCFLAGS = -c -ffreestanding -nostdlib -lgcc

SRC=$(wildcard src/*.c)
OBJ=$(SRC:src%.c=build%.o)

all: init BootDisk.img

init:
	mkdir -p build

run: all
	qemu-system-i386 -drive format=raw,if=floppy,file=BootDisk.img -m 128

debug: all
	bochs -f bochsrc.bxrc -q

build/%.o: src/%.c
	$(CC) $(CCFLAGS) -o $@ $<

BOOTLOADER.BIN:
	nasm src/bootloader.asm -o build/BOOTLOADER.BIN

LOADER.SYS:
	nasm src/loader.asm -o build/LOADER.SYS

KERNEL.SYS: $(OBJ)
	$(LD) -T src/linker.ld -o build/kernel.elf $(OBJ)
	objcopy -O binary build/kernel.elf build/KERNEL.SYS

BootDisk.img: BOOTLOADER.BIN LOADER.SYS KERNEL.SYS
	dd if=/dev/zero of=BootDisk.img bs=512 count=2880
	sudo losetup /dev/loop0 BootDisk.img
	sudo mkdosfs -F 12 /dev/loop0
	sudo mount /dev/loop0 /mnt -t msdos -o "fat=12"
	sudo cp build/LOADER.SYS /mnt
	sudo cp build/KERNEL.SYS /mnt
	sudo umount /mnt
	sudo losetup -d /dev/loop0
	dd if=build/BOOTLOADER.BIN of=BootDisk.img bs=512 count=1 conv=notrunc
