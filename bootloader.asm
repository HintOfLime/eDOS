;+---------------------------------+
;|  SECTOR 1 - Primary Bootloader  |
;+---------------------------------+

[bits 16]
[org 0]

start:
	jmp 0x07C0:loader	; Jump over OEM block
	nop			; This is supposedly good practice?
 
;*************************************************;
;	OEM Parameter block / BIOS Parameter Block    ;
;*************************************************;
 
TIMES 0Bh-$+start DB 0

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

loader:
	; Set Data Segments
	mov ax, 0x07C0
	mov	ds, ax
	mov	es, ax
	
	mov [DISK_VARS.DISK], dl					; Set disk
	
	; mov ax, 0
	; mov cx, 0x0100
	; test_loop:
	;	 call Debug
	;	 inc ax
	;	 loop test_loop
	;	
	; cli
	; hlt
	
	;mov si, DISK_VARS.FILENAME
	;call Print
	
	call Disk.Load_RD
	
	call Disk.Search_For_File					; Find Second Stage
	
	call Disk.Load_FAT							; Load FAT
	
	call Disk.Cluster_To_CHS					; Convert Second Stage Cluster to CHS				 --- Returns correct value but hangs ---
	
	mov ax, [bpbSectorsPerCluster]
	mov [DISK_VARS.SECTORS_TO_READ], ax
	
	mov ax, 0x0000
	mov [DISK_VARS.MEM_OFFSET], ax
	mov ax, 0x0A00
	mov [DISK_VARS.MEM_SEGMENT], ax
	
	call Disk.ReadSectors						; Read Second Stage Cluster
	
	mov ax, [0xA000]
	call Debug
	mov ax, [0xA001]
	call Debug
	
	cli
	hlt
	
	;jmp 0x0A00:0x0000							; Jump to Second Stage

; ----- Routines -----
; Prints a string
; SI = Start address of string
;Print:
	;push ax
	;.Loop:
	;	lodsb
	;	or al, al
	;	jz .Exit
	;	mov	ah, 0x0e
	;	int	0x10
	;	jmp .Loop
	;.Exit:
	;	pop ax
	;	ret

; Prints AX as hex
; AX = Value to print
Debug:
	push ax
	push cx
	mov cx, 4
	
	;mov si, SPACE
	;call Print
	
	.loop:
		rol ax, 4
		call .LowALOut
	
	loop .loop
	
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
	

Disk:
	.Reset:
		pusha
		mov ah, 0
		mov dl, [DISK_VARS.DISK]
		int 0x13
		jc .Error
		popa
		ret

	.ReadSectors:
		pusha
		mov ah, 0x02 							; BIOS read sector function
		mov al, [DISK_VARS.SECTORS_TO_READ]		; Select number of segments
		push ax
		mov ch, [DISK_VARS.CYLINDER] 			; Select cylinder
		mov cl, [DISK_VARS.SECTOR] 				; Select sector to read
		mov dh, [DISK_VARS.HEAD] 				; Select head
		mov dl, [DISK_VARS.DISK]				; Select disk
		mov bx, [DISK_VARS.MEM_OFFSET]			; Select memory offset
		push bx
		mov bx, [DISK_VARS.MEM_SEGMENT]			; Select memory segment
		mov es, bx
		pop bx
		int 0x13 								; BIOS interrupt
		jc .Error 								; Jump if error
		pop dx
		cmp dl, al 								; If AL ( sectors read ) != DL ( sectors expected )
		jne .Error 								; Jump to error
		popa
		ret

	.Search_For_File:
		pusha
		mov cx, [bpbRootEntries]        		; Get the number of entries. If we reach 0, file doesnt exist
		mov di, 0x0200        					; Root directory was loaded here
		mov si, [DISK_VARS.FILENAME]
		.Loop:
			push cx
			mov cx, 11
			push di
			push si
			repe cmpsb
			pop si
			pop di
			pop cx
			je .Exit
			add di, 32            				; They dont match, so go to next entry (32 bytes)
			loop .Loop
			jmp Disk.Error           			; No more entrys left, file doesnt exist
		.Exit:
			mov ax, WORD [di + 26]				; Get First Logical Cluster
			mov WORD [DISK_VARS.CLUSTER], ax
			popa
			ret
	
	.Load_RD:
		push ax
		
		; Compute size of Root Directory
		mov ax, 32	        						; ( 32 byte directory entry
		mul WORD [bpbRootEntries]  					;   * Number of root entrys )
		div WORD [bpbBytesPerSector] 				; / Get sectors used by root directory
		mov [DISK_VARS.SECTORS_TO_READ], al			; Set as parameter
		mov [RD_START], ax
		
		; Compute location of Root Directory
		mov al, [bpbNumberOfFATs]  					; Get number of FATs (Usually 2)
		mul WORD [bpbSectorsPerFAT]  				; Number of FATs * sectors per FAT
		add ax, WORD [bpbReservedSectors] 			; Add reserved sectors
		mov [DISK_VARS.LBA], al						; Set as parameter
		mov [RD_SIZE], ax
		call Disk.LBA_To_CHS						; Convert to CHS for disk read
		
		mov ax, 0x0000
		mov [DISK_VARS.MEM_OFFSET], ax
		mov ax, 0x07E0
		mov [DISK_VARS.MEM_SEGMENT], ax
		
		call Disk.Reset								; Reset disk
		call Disk.ReadSectors						; Load root directory
	
		pop ax
		ret
	
	.Load_FAT:
		pusha
		mov ax, 0
		mov al, [bpbNumberOfFATs]				; Number of FATs
		mul WORD [bpbSectorsPerFAT]				; Multiply by Sectors Per FAT
		mov BYTE [DISK_VARS.SECTORS_TO_READ], al
		
		mov ax, [bpbReservedSectors]			; Read sectors immediatley after the reserved sectors
		mov [DISK_VARS.LBA], ax
		
		call Disk.LBA_To_CHS
		
		mov ax, 0x0000
		mov [DISK_VARS.MEM_OFFSET], ax
		mov ax, 0x07E0
		mov [DISK_VARS.MEM_SEGMENT], ax
		
		call Disk.ReadSectors
		popa
		ret
	
	 .Cluster_To_LBA:							; LBA = (Cluster - 2 ) * SectorsPerCluster	???
		pusha
		mov ax, WORD [DISK_VARS.CLUSTER]
		add ax, [RD_START]
		add ax, [RD_SIZE]
		sub ax, 2                          		; Subtract 2 from cluster number
		mov cx, 0
		mov cl, BYTE [bpbSectorsPerCluster]     ; Get sectors per cluster
		mul cx                                  ; Multiply
		mov [DISK_VARS.LBA], ax
		call Debug
		popa
		ret
		
	.LBA_To_CHS:
		pusha
		;Absolute Sector 	= 	(LBA  %  SectorsPerTrack) + 1
		;Absolute Head   	= 	(LBA  /  SectorsPerTrack) % Heads
		;Absolute Cylinder 	= 	 LBA  / (SectorsPerTrack  * Heads)
		
		mov dx, 0
		mov ax, WORD [DISK_VARS.LBA]
		div WORD [bpbSectorsPerTrack]			; (LBA % SectorsPerTrack)
		inc dx									; + 1
		mov BYTE [DISK_VARS.SECTOR], dl
		
		mov dx, 0																					; --- Hangs here when converting from cluster ---
		mov ax, WORD [DISK_VARS.LBA]
		div WORD [bpbSectorsPerTrack]			; (LBA / SectorsPerTrack)
		div WORD [bpbHeadsPerCylinder]			; % Heads
		mov BYTE [DISK_VARS.HEAD], dl

		mov dx, 0
		mov ax, WORD [bpbSectorsPerTrack]
		mul WORD [bpbHeadsPerCylinder]			; (SectorsPerTrack * Heads)
		mov cx, ax
		mov ax, WORD [DISK_VARS.LBA]			; LBA / ()
		div cx
		mov BYTE [DISK_VARS.CYLINDER], al
		
		popa
		ret
		
	.Cluster_To_CHS:
		call Disk.Cluster_To_LBA				; HANGS HERE!!! (because cluster is 0 so LBA goes negative on SUB AX, 2)
		call Disk.LBA_To_CHS
		ret
		
	.Error:
		;mov si, DISK_VARS.ERROR_MSG
		;call Print
		cli
		hlt
		
; ----- Variables -----
DISK_VARS:
	.CYLINDER:
		db 0
	.HEAD:
		db 0
	.DISK:
		db 0
	.SECTOR:
		db 0
	.SECTORS_TO_READ:
		db 0
	.MEM_SEGMENT:
		dw 0x07E0
	.MEM_OFFSET:
		dw 0x0000
	.FILENAME:
		db "SECTOR2 SYS", 0
	.CLUSTER:
		dw 0
	.LBA:
		dw 0
	;.ERROR_MSG:
		;db "Disk Error", 0
SPACE:
	db " ", 0
RD_START:
	dw 0
RD_SIZE:
	dw 0
	
times 510 - ($-$$) db 0
dw 0xaa55