%define IMAGE_RMODE_BASE 0x00003000
%define IMAGE_PMODE_BASE 0x00100000

[bits 16]

LoadELF:
	mov si, FILENAME
	mov bx, 0x0000
	mov ax, IMAGE_RMODE_BASE/10
	call Disk.GetFile
	
	; Check magic ELF double word
	mov edx, [MagicELF]
	push ds
	mov ax, IMAGE_RMODE_BASE/10
	mov ds, ax
	mov eax, [0x0]
	cmp eax, edx
	jne ELFError

	; Get and store entry point
	mov eax, [20]
	bswap eax

	; Get beginning of program header
	mov ebx, [0x1C]
	bswap ebx
	
	; Get text section offset
	mov edx, [ebx+4]					; This causes an error for some reason
	bswap edx
	
	pop ds
	
	mov [EntryPoint], eax
	mov [TextOffset], edx

	ret
	
ELFError:
	pop ds
	mov si, ELFErrorMsg
	call Print
	cli
	hlt
	
MagicELF: dd 0x464C457F
ELFErrorMsg: db "Invalid ELF File!", 0x0A, 0x0D, 0
EntryPoint: dd 0
TextOffset: dd 0
ImageSize: dw 1 

[bits 32]

MoveELF:
	mov	eax, DWORD [ImageSize]			; Image size in sectors
	movzx ebx, WORD [0x7C00 + 11]		; Bytes per sector
	mul ebx
	mov ebx, 4
	div ebx
	cld
	mov esi, IMAGE_RMODE_BASE			; Current image location
	mov edi, IMAGE_PMODE_BASE			; Target Location
	mov ecx, eax
	rep movsd                   		; Copy image to its protected mode address
	ret