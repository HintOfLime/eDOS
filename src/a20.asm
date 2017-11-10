[bits 16]

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