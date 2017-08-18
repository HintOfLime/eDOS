;+---------------------------------+
;|  ROUTINES - Video               |
;+---------------------------------+

[bits 32]

%define	VIDMEM	0xB8000					; Video memory address
%define COLUMNS	80				
%define ROWS	25
%define	CHAR_ATTRIB 00001111b			; White in black

CurX:	db 0
CurY:	db 0

ClrScreen:
	pusha
	
	xor eax, eax
	xor ecx, ecx
	
	mov al, BYTE COLUMNS
	mov cl, BYTE ROWS
	mul cx								; Columns * Rows
	mov cx, ax							; = Number of words
	
	mov al, 0							; Null character
	mov ah, CHAR_ATTRIB					; Character attribute
	
	mov edi, VIDMEM						; Get pointer to video memory
	
	rep stosw
	
	mov al, 0
	mov [CurX], al
	mov [CurY], al
	
	popa
	ret

PutS:
	pusha
	.Loop:
		lodsb
		or al, al
		jz .Exit
		cmp al, 0x0A
		jne .skip1
		call CarriageReturn
		jmp .Loop
		
		.skip1:
		cmp al, 0x0D
		jne .skip2
		call NewLine
		jmp .Loop
		
		.skip2:
		call PutC
		jmp .Loop
	.Exit:
	popa
	ret

CarriageReturn:
	pusha
	mov al, 0
	mov [CurX], al
	popa
	ret
	
NewLine:
	pusha
	mov al, [CurY]
	add al, 1
	mov [CurY], al
	popa
	ret

PutC:
	pusha
	
	mov bl, al
	
	mov edi, VIDMEM						; Get pointer to video memory
	xor	eax, eax						; Clear eax
	
	mov	ecx, COLUMNS*2					; Mode 7 has 2 bytes per char, so its COLS*2 bytes per line
	mov	al, BYTE [CurY]					; Get y pos
	mul ecx								; CurY * COLUMNS
	push eax							; Save Y offset
	
	mov	al, BYTE [CurX]					; Multiply CurX by 2 because it is 2 bytes per char
	mov	cl, 2
	mul	cl
	pop	ecx								; Pop Y offset
	add	eax, ecx
	
	add edi, eax
	
	mov	[edi], bl						; Print character
	mov	[edi+1], BYTE CHAR_ATTRIB		; Character attribute
	
	mov al, BYTE [CurX]
	add al, 1
	cmp al, 80
	jge .skip
	mov BYTE [CurX], al
	jmp .end
	.skip:
	xor al, al
	mov BYTE [CurX], al
	mov al, BYTE [CurY]
	add al, 1
	mov BYTE [CurY], al
	.end:
	popa
	ret