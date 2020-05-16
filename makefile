ALL: init BootDisk.img

init:
	mkdir -p build

run: ALL
	qemu-system-i386 -drive format=raw,if=floppy,file=BootDisk.img -m 128

debug: ALL
	bochs -f bochsrc.bxrc -q

BOOTLOADER.BIN:
	nasm src/bootloader.asm -o build/BOOTLOADER.BIN

LOADER.SYS:
	nasm src/loader.asm -o build/LOADER.SYS

KERNEL.SYS:
	# I should start using wildcards, this is ridiculous
	/opt/cross/bin/i686-elf-gcc -c -ffreestanding -nostdlib -o build/kernel.o src/kernel.c -lgcc
	/opt/cross/bin/i686-elf-gcc -c -ffreestanding -nostdlib -o build/interrupts.o src/interrupts.c -lgcc 
	/opt/cross/bin/i686-elf-gcc -c -ffreestanding -nostdlib -o build/timers.o src/timers.c -lgcc
	/opt/cross/bin/i686-elf-gcc -c -ffreestanding -nostdlib -o build/video.o src/video.c -lgcc
	/opt/cross/bin/i686-elf-gcc -c -ffreestanding -nostdlib -o build/ports.o src/ports.c -lgcc
	/opt/cross/bin/i686-elf-gcc -c -ffreestanding -nostdlib -o build/keyboard.o src/keyboard.c -lgcc
	/opt/cross/bin/i686-elf-gcc -c -ffreestanding -nostdlib -o build/utility.o src/utility.c -lgcc
	/opt/cross/bin/i686-elf-gcc -c -ffreestanding -nostdlib -o build/memory.o src/memory.c -lgcc
	/opt/cross/bin/i686-elf-ld -T src/linker.ld -o build/kernel.elf build/kernel.o build/video.o build/ports.o build/interrupts.o build/timers.o build/keyboard.o build/utility.o build/memory.o
	objcopy -O binary build/kernel.elf build/KERNEL.SYS


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
