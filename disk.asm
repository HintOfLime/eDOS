;+---------------------------------+
;|  ROUTINES - Disk                |
;+---------------------------------+

[bits 16]

; TODO:
;	Add repeats to ReadSectors // Problematic because can't use CX to loop because it is needed for INT 0x13
;	Increase max file size // Not needed at the moment
;	FAT16 // Maybe I'll get round to this so I can USB drives without wasting gigabytes of space

Disk:
	; --- Reset disk ---
	; > DL = Disk
	.Reset:
		push ax
		push cx
		mov cx, 3
		mov ah, 0
		.ResetTryAgain:
		int 0x13
		jc .ResetFail
		pop cx
		pop ax
		ret
		.ResetFail:
		loop .ReadTryAgain
		jmp Disk.Error
	
	
	; --- Read sectors ---
	; > AL = Number of sectors
	; > BX = Memory offset
	; > CH = Cylinder
	; > CL = Sector
	; > DH = Head
	; > DL = Disk
	; > ES = Mem segment
	.ReadSectors:
		push dx
		push bx
		
		.ReadTryAgain:
		push ax
		mov ah, 0x02
		int 0x13								; Read disk
		jc .ReadFail	 						; Jump if error
		pop bx
		cmp al, bl
		jne .ReadFail 							; Jump if error
		pop bx
		pop dx
		ret
		
		.ReadFail:
		jmp Disk.Error							; Jump to error 'handler'
	
	; --- Convert LBA to CHS ---
	; > AX = LBA
	; < CL = Sector
	; < CH = Cylinder
	; < DH = Head
	.LBAToCHS:
		; Absolute Sector 	= 	(LBA  %  SectorsPerTrack) + 1
		; Absolute Head   	= 	(LBA  /  SectorsPerTrack) % Heads
		; Absolute Cylinder 	= 	 LBA  / (SectorsPerTrack  * Heads)
		push dx		; Disk
		push bx		; Memory offset
		mov bx, ax
		mov [LBA], ax
		
		mov dx, 0
		div WORD [bpbSectorsPerTrack]			; (LBA % SectorsPerTrack)
		inc dx									; + 1
		mov cl, dl
		push cx		; Sector
		
		mov dx, 0
		mov ax, bx
		div WORD [bpbSectorsPerTrack]			; (LBA / SectorsPerTrack)
		mov dx, 0
		div WORD [bpbHeadsPerCylinder]			; % Heads
		mov dh, dl
		push dx		; Head
		
		mov dx, 0
		mov ax, WORD [bpbSectorsPerTrack]
		mul WORD [bpbHeadsPerCylinder]			; (SectorsPerTrack * Heads)
		mov cx, ax
		mov ax, [LBA]							; LBA / ()
		div cx
		mov ch, al

		pop ax		; Head
		mov dh, ah
		pop ax		; Sector
		mov cl, al
		pop bx
		pop ax		; Disk
		mov dl, al
		
		ret
	
	; --- Convert Cluster to LBA ---
	; > AX = Cluster
	; < AX = LBA
	.ClusterToLBA:	 							; LBA = (Cluster - 2 ) * SectorsPerCluster
		push cx
		add ax, [RD_START]
		add ax, [RD_SIZE]
		sub ax, 2                          		; Subtract 2 from cluster number
		mov cx, 0
		mov cl, BYTE [bpbSectorsPerCluster]     ; Get sectors per cluster
		mul cx                                  ; Multiply
		pop cx
		ret
		
	; --- Load Root Directory ---
	; > DL = Disk
	.LoadRD:
		; Compute size of Root Directory
		mov ax, 32	        					; ( 32 byte directory entry
		mul WORD [bpbRootEntries]  				;   * Number of root entrys )
		mov dx, 0
		div WORD [bpbBytesPerSector] 			; / sectors used by root directory
		mov [RD_SIZE], ax						; AL now equals sectors to read
		push ax
		
		; Compute location of Root Directory
		mov al, [bpbNumberOfFATs]  				; Get number of FATs (Usually 2)
		mul WORD [bpbSectorsPerFAT]  			; Number of FATs * sectors per FAT
		add ax, WORD [bpbReservedSectors] 		; Add reserved sectors
		mov [RD_START], ax						; AX now equals the LBA
		call Disk.LBAToCHS						; Convert to CHS for disk read

		pop ax
		mov bx, [MEM_OFFSET]
		
		call Disk.Reset							; Reset disk
		call Disk.ReadSectors					; Load root directory
		
		ret
	
	; --- Search for file ---
	; > SI = Filename string pointer
	; < AX = Cluster
	.SearchRD:
		mov cx, [bpbRootEntries]
		mov di, [MEM_OFFSET]
		mov si, FILENAME
		.Loop:
			push cx
			mov cx, 11
			push si
			push di
			repe cmpsb
			pop di
			pop si
			pop cx
			je .Done
			add di, 32
			loop .Loop
			jmp Disk.Error
		.Done:
			mov ax, WORD [di + 26]
			ret
	
	; --- Load FAT into memory ---
	; > DL = Disk
	.LoadFAT:
		push ax
		mov ax, 0
		mov al, [bpbNumberOfFATs]				; Number of FATs
		mul WORD [bpbSectorsPerFAT]				; Multiply by Sectors Per FAT
		push ax
		
		mov ax, [bpbReservedSectors]			; Read sectors immediatley after the reserved sectors
		
		call Disk.LBAToCHS
		
		mov bx, [MEM_OFFSET]
		pop ax
		call Disk.ReadSectors
		
		pop ax
		ret
	
	; --- Load file clusters into memory ---
	; > AX = First cluster
	; > DL = Disk
	; > ES = Memory segment
	; > BX = Memory offset
	.LoadFile:
		mov dl , [DISK]
		push ax									; Push cluster
		call Disk.ClusterToLBA					; Convert cluster to LBA
		call Disk.LBAToCHS						; Convert LBA to CHS
		mov al, [bpbSectorsPerCluster]			; Sectors to read
		call Disk.ReadSectors					; Read cluster
		
		; Compute next cluster
		
		mov ax, [bpbBytesPerSector]
		mul WORD [bpbSectorsPerCluster]
		add bx, ax								; Increase read location
		pop ax									; Pop cluster
		push bx									; Push read location
		push dx									; Push disk
		
		mov cx, ax								; Copy to CX
		mov dx, ax								; Copy to DX
		shr dx, 1								; Divide by 2
		add cx, dx								; Sum for 3/2
		mov bx, [MEM_OFFSET]							; Location of FAT in memory
		add bx, cx								; Index into FAT
		mov dx, WORD [bx]						; Read from FAT
		test ax, 1								; Test if odd
		jnz .Odd
		
		.Even:
			and dx, 0000111111111111b
			jmp .End
			
		.Odd:
			shr dx, 0x0004
			
		.End:
			mov ax, dx
			cmp dx, 0x0FF0
			pop dx								; Pop disk
			pop bx								; Pop read location
			jb  .LoadFile
			ret
	
	; --- Load file into memory ---
	; MAX SIZE = 64kb // May fix this
	; > AX = Offset
	; > BX = Segment
	; > DL = Disk
	; > SI = Filename string pointer
	.GetFile:
		push es
		push ax
		push bx
		
		call Disk.LoadRD
		
		call Disk.SearchRD
		
		call Disk.LoadFAT
		
		pop bx
		pop cx
		mov es, cx
		call Disk.LoadFile
		
		pop es
		ret
	
	; --- Print error message and halt ---
	.Error:
		mov si, ERROR_MESSAGE
		call Print
		
		cli
		hlt
	
ERROR_MESSAGE:
	db "Disk error!", 0