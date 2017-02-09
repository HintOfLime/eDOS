;+---------------------------------+
;| SECTOR 2 - Secondary Bootloader |	Currently for testing primary bootloader
;+---------------------------------+

[bits 16]
[org 0x0000]


; ----- Main -----

; Setup Segments and Stack
cli
mov ax, 0x0A00
mov	ds, ax
mov	es, ax
mov ax, 0x0000
mov ss, ax
mov sp, 0xFFFF
sti

mov si, TestString
call Print

mov si, FILENAME							; Reload file
;call Print
mov ax, 0x0200								; Offset:	0x0200
mov bx, 0x0A00								; Segment:	0x0A00
;int 20h
call 0x07C0:0x0000							; Far Call

;jmp 0x0A00:0x0000							; Jump back to start

mov si, 0x0200
call Print

cli
hlt


; ----- Routines -----
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
		
; ----- Data -----
FILENAME:
	db "TEST    TXT", 0
TestString:
	db "Hello World!", 0x0A, 0x0D, 0