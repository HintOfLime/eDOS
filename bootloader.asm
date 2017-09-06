;+---------------------------------+
;|  SECTOR 1 - Primary Bootloader  |
;+---------------------------------+

[bits 16]
[org 0x0000]

Start:
	jmp 0x07C0:Loader							; Jump over OEM block
	nop

;*************************************************;
;	OEM Parameter block / BIOS Parameter Block    ;
;*************************************************;
TIMES 0Bh-$+Start DB 0

bpbBytesPerSector:  	DW 512					; 11 Byte offset
bpbSectorsPerCluster: 	DB 1					; 13
bpbReservedSectors: 	DW 1					; 14
bpbNumberOfFATs: 		DB 2					; 16
bpbRootEntries: 		DW 224					; 17
bpbTotalSectors: 		DW 2880					; 19
bpbMedia: 	       		DB 0xF0					; 21
bpbSectorsPerFAT: 		DW 9					; 22
bpbSectorsPerTrack: 	DW 18					; 24
bpbHeadsPerCylinder: 	DW 2					; 26
bpbHiddenSectors:       DD 0					; 28
bpbTotalSectorsBig:     DD 0					; 32
bsDriveNumber: 	        DB 0					; 36
bsUnused: 	        	DB 0					; 37
bsExtBootSignature: 	DB 0x29					; 38
bsSerialNumber:	        DD 0xa0a1a2a3			; 42
bsVolumeLabel: 	        DB "EDOS       "		; 43
bsFileSystem: 	        DB "FAT12   "			; 44
;*************************************************;

Loader:
	; Setup Segments and Stack
	cli
	mov ax, 0x07C0
	mov	ds, ax
	mov	es, ax
	mov ax, 0x0000
	mov ss, ax
	mov sp, 0xFFFF
	sti

	mov [DISK], dl							; Set disk

	mov si, FILENAME
	mov bx, 0x0000							; Offset
	mov ax, 0x0050							; Segment
	call Disk.GetFile

	jmp 0x0000:0x0500						; Jump to Second Stage

; ----- Routines -----
%include "disk.asm"

Print:
	push ax
	.Loop:
		lodsb
		or al, al
		jz .Exit
		mov	ah, 0x0e
		int	0x10
		jmp .Loop
	.Exit:
		pop ax
		ret

; ----- Variables -----
DISK EQU 0xF000
LBA EQU 0xF002
RD_START EQU 0xF004
RD_SIZE EQU 0xF006

MEM_OFFSET:
	dw 0x0200

FILENAME:
	db "LOADER  SYS"

times 510 - ($-$$) db 0
dw 0xAA55
