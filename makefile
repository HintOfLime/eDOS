ALL: init BootDisk.img

init:
	mkdir -p build

run: ALL
	qemu-system-i386 -drive format=raw,if=floppy,file=BootDisk.img

BOOTLOADER.BIN:
	nasm src/bootloader.asm -o build/BOOTLOADER.BIN

LOADER.SYS:
	nasm src/loader.asm -o build/LOADER.SYS

kernel.o:
	/usr/local/bin/i686-elf-gcc -ffreestanding -nostdlib -g -o build/kernel.o -lgcc -T src/linker.ld src/kernel.c

KERNEL.SYS: kernel.o
	objcopy -O binary build/kernel.o build/KERNEL.SYS

BootDisk.img: BOOTLOADER.BIN LOADER.SYS KERNEL.SYS
	dd if=/dev/zero of=BootDisk.img bs=512 count=2880
	sudo losetup /dev/loop0 BootDisk.img
	sudo mkdosfs -F 12 /dev/loop0
	sudo mount /dev/loop0 /mnt -t msdos -o "fat=12"
	sudo mv build/LOADER.SYS /mnt
	sudo mv build/KERNEL.SYS /mnt
	sudo umount /mnt
	sudo losetup -d /dev/loop0
	dd if=build/BOOTLOADER.BIN of=BootDisk.img bs=512 count=1 conv=notrunc
