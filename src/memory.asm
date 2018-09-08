[bits 16]

; Need to implement more A20 methods

; Enable A20 through keyboard
EnableA20_Keyboard_Out:
	cli
	pusha

	call    wait_input
	mov     al,0xAD
	out     0x64,al				; Disable keyboard
	call    wait_input

	mov     al,0xD0
	out     0x64,al				; Tell controller to read output port
	call    wait_output

	in      al,0x60
	push    eax					; Get output port data and store it
	call    wait_input

	mov     al,0xD1
	out     0x64,al				; Tell controller to write output port
	call    wait_input

	pop     eax
	or      al,2				; Set bit 1 (enable A20)
	out     0x60,al				; Write data back to the output port

	call    wait_input
	mov     al,0xAE				; Enable keyboard
	out     0x64,al

	call    wait_input

	popa
	sti
	ret

; Wait for input buffer to be clear
wait_input:
	in      al,0x64
	test    al,2
	jnz     wait_input
	ret

; Wait for output buffer to be clear
wait_output:
	in      al,0x64
	test    al,1
	jz      wait_output
	ret

A20Error:
	mov si, A20ErrorMsg
	call Print
	cli
	hlt

; > ES:DI = Map location
GetMemoryMap:
	pusha
	push di

	mov ebx, 0
	mov bp, 0

	; 'Magic words'
	mov edx, 0x0534D4150
	mov eax, 0xe820
	
	; Set parameters
	mov [es:di + 20], DWORD 1
	mov ecx, 24
	int 0x15

	; Make sure nothing weird happened
	jc .error
	mov edx, 0x0534D4150
	cmp eax, edx
	jne .error
	test ebx, ebx
	je .error
	jmp .entry

	; Get next entry
	.loop:
		mov eax, 0xe820
		mov [es:di + 20], dword 1
		mov ecx, 24
		int 0x15
		jc .exit
		mov edx, 0x0534D4150

	; Check entry is valid
	.entry:
		jcxz .skip
		cmp cl, 20
		jbe .notext
		test BYTE [es:di + 20], 1
		je .skip

	; Double check
	.notext:
		mov ecx, [es:di + 8]
		or ecx, [es:di + 12]
		jz .skip
		inc bp
		add di, 24

	; Check if list is finished
	.skip:
		test ebx, ebx
		jne .loop

	.exit:
		pop di
		mov [es:di - 4], bp
		clc
		popa
		ret
	
	; Print error message and halt
	.error:
		mov si, MEMORY_ERROR_MESSAGE
		call Print

		cli
		hlt

MEMORY_ERROR_MESSAGE:
	db "Memory error!", 0