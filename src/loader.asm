;+---------------------------------+
;| SECTOR 2 - Secondary Bootloader |
;+---------------------------------+

[bits 16]
[org 0x0500]

; ----- Main -----
; Setup Segments and Stack
cli
mov ax, 0x0000
mov	ds, ax
mov	es, ax
mov ax, 0x9000
mov ss, ax
mov sp, 0xFFFF
sti

mov si, Stg2Msg
call Print

call EnableA20_Keyboard_Out

; Check if we memory above 1Mb is wrapped around
push ds
mov ax, 0xFFFF
mov ds, ax
mov ax, [0x7E0E]
pop ds
mov bx, [0x7DFE]
cmp ax, bx
je A20Error						; If we get the magic boot number then we must have wrapped around

; Load kernel into memory
mov si, FILENAME
mov bx, 0x0000					; Offset
mov ax, 0x0300					; Segment
call Disk.GetFile

; Load GDT
lgdt [gdt_pointer]

; Switch to protected mode
cli
mov		eax, cr0
or		eax, 1
mov		cr0, eax

jmp	0x8:Pmode

; ----- Routines -----

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

%include "src/disk.asm"
%include "src/a20.asm"

; Prints a string
; SI = Start address of string
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

; Prints AX as hex
; AX = Value to print
Debug:
	push ax
	push cx
	mov cx, 4
	.loop:
		rol ax, 4
		call .LowALOut
	loop .loop
	mov ah, 0x0e
	mov al, 0x0A
	int 0x10
	mov al, 0x0D
	int 0x10
	pop cx
	pop ax
	ret

	.LowALOut:
		push ax
		and ax, 0x000F
		cmp al, 0x9
		jg .abcdef
		add al, 0x30
		jmp .skip
		.abcdef:
		add al, 0x37
		.skip:
		mov ah, 0x0e
		int 0x10
		pop ax
		ret

; ----- GDT -----
 gdt_data:
; Null descriptor
	dd 0 							; null descriptor--just fill 8 bytes with zero
	dd 0

; Code descriptor:					; code descriptor. Right after null descriptor
	dw 0FFFFh 						; limit low
	dw 0 							; base low
	db 0 							; base middle
	db 10011010b 					; access
	db 11001111b 					; granularity
	db 0 							; base high

; Data descriptor:					; data descriptor
	dw 0FFFFh 						; limit low (Same as code)
	dw 0 							; base low
	db 0 							; base middle
	db 10010010b 					; access
	db 11001111b 					; granularity
	db 0							; base high
end_of_gdt:

gdt_pointer:
	dw end_of_gdt - gdt_data - 1 	; limit (Size of GDT)
	dd gdt_data 					; base of GDT

DISK EQU 0xF000
LBA EQU 0xF002
RD_START EQU 0xF004
RD_SIZE EQU 0xF006

FILENAME:
	db "KERNEL  SYS"

MEM_OFFSET:
	dw 0x1000

Stg2Msg: db "Second stage loaded!", 0x0A, 0x0D, 0
A20ErrorMsg: db "A20 error!", 0x0A, 0x0D, 0

[bits 32]

%include "src/video.asm"

Pmode:
mov		ax, 0x10					; Set data segments to data selector (0x10)
mov		ds, ax
mov		ss, ax
mov		es, ax
mov		esp, 0x90000

call ClrScreen

mov esi, Stg3Msg
call PutS

; Copy kernel to 1MB (0x10000)
mov	eax, dword 2000	; This should be the size of the kernel, temporarily hardcoded to 1MB
movzx	ebx, word [bpbBytesPerSector]
mul	ebx
mov	ebx, 4
div	ebx
cld
mov esi, 0x3000		; Initial location
mov	edi, 0x100000	; Final location
mov	ecx, eax
rep	movsd

mov esi, Stg4Msg
call PutS

xchg bx, bx

cli
jmp 0x100000

Stg3Msg: db "Now in protected mode!", 0x0A, 0x0D, 0
Stg4Msg: db "Jumping to kernel!", 0x0A, 0x0D, 0
