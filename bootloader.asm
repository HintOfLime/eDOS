;+---------------------------------+
;|  SECTOR 1 - Primary Bootloader  |
;+---------------------------------+

[bits 16]
[org 0x0000]

Start:
	jmp 0x07C0:Loader							; Jump over OEM block
	nop											; This is supposedly good practice?
 
;*************************************************;
;	OEM Parameter block / BIOS Parameter Block    ;
;*************************************************;
TIMES 0Bh-$+Start DB 0

bpbBytesPerSector:  	DW 512
bpbSectorsPerCluster: 	DB 1
bpbReservedSectors: 	DW 1
bpbNumberOfFATs: 		DB 2
bpbRootEntries: 		DW 224
bpbTotalSectors: 		DW 2880
bpbMedia: 	       		DB 0xF0
bpbSectorsPerFAT: 		DW 9
bpbSectorsPerTrack: 	DW 18
bpbHeadsPerCylinder: 	DW 2
bpbHiddenSectors:       DD 0
bpbTotalSectorsBig:     DD 0
bsDriveNumber: 	        DB 0
bsUnused: 	        	DB 0
bsExtBootSignature: 	DB 0x29
bsSerialNumber:	        DD 0xa0a1a2a3
bsVolumeLabel: 	        DB "EDOS       "
bsFileSystem: 	        DB "FAT12   "
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
	mov bx, 0x0000							; Offset:	0x0000
	mov ax, 0x1000							; Segment:	0x1000
	call Disk.GetFile
	
	jmp 0x1000:0x0000						; Jump to Second Stage

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
	db "SECTOR2 SYS", 0
	
times 510 - ($-$$) db 0
dw 0xAA55