;+---------------------------------+
;| SECTOR 2 - Secondary Bootloader |
;+---------------------------------+

[bits 16]
[org 0x0000]


; ----- Main -----

; Setup Segments and Stack
cli
mov ax, 0x1000
mov	ds, ax
mov	es, ax
mov ax, 0x0000
mov ss, ax
mov sp, 0xFFFF
sti

mov si, TestString
call Print

cli
hlt

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

TestString: db "Hello World!", 0x0A, 0x0D, 0
times 65536 - ($-$$) db 0xFF