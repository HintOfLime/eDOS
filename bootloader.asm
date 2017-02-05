;+---------------------------------+
;|  SECTOR 1 - Primary Bootloader  |
;+---------------------------------+

[bits 16]
[org 0x0000]

start:
	jmp 0x07C0:loader							; Jump over OEM block
	nop											; This is supposedly good practice?
 
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
	; Setup Segments and Stack
	cli
	mov ax, 0x07C0
	mov	ds, ax
	mov	es, ax
	mov ax, 0x0000
	mov ss, ax
	mov sp, 0xFFFF
	sti
	
	mov [DISK_VARS.DISK], dl					; Set disk
	
	mov ax, Disk.Get_File
	mov [0x0001], ax
	
	mov si, [DISK_VARS.FILENAME]
	mov ax, 0x0000								; Offset:	0x0000
	mov bx, 0x0A00								; Segment:	0x0A00
	call Disk.Get_File
	
	jmp 0x0A00:0x0000							; Jump to Second Stage

; ----- Routines -----
Disk:
	.Reset:
		mov ah, 0
		mov dl, [DISK_VARS.DISK]
		int 0x13
		jc .Error
		ret

	.ReadSectors:
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
		ret
	
	.Load_RD:
		push ax
		
		; Compute size of Root Directory
		mov ax, 32	        						; ( 32 byte directory entry
		mul WORD [bpbRootEntries]  					;   * Number of root entrys )
		mov dx, 0
		div WORD [bpbBytesPerSector] 				; / Get sectors used by root directory
		mov [DISK_VARS.SECTORS_TO_READ], al			; Set as parameter
		mov [DISK_VARS.RD_START], ax
		
		; Compute location of Root Directory
		mov al, [bpbNumberOfFATs]  					; Get number of FATs (Usually 2)
		mul WORD [bpbSectorsPerFAT]  				; Number of FATs * sectors per FAT
		add ax, WORD [bpbReservedSectors] 			; Add reserved sectors
		mov [DISK_VARS.LBA], ax						; Set as parameter
		mov [DISK_VARS.RD_SIZE], ax
		call Disk.LBA_To_CHS						; Convert to CHS for disk read
		
		mov ax, 0x0000
		mov [DISK_VARS.MEM_OFFSET], ax
		mov ax, 0x07E0
		mov [DISK_VARS.MEM_SEGMENT], ax
		
		call Disk.Reset								; Reset disk
		call Disk.ReadSectors						; Load root directory
	
		pop ax
		ret
	
	.Search_For_File:
		mov cx, [bpbRootEntries]        		; Get the number of entries. If we reach 0, file doesnt exist
		mov di, 0x0200        					; Root directory was loaded here
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
			ret
	
	.Load_FAT:
		mov ax, 0
		mov al, [bpbNumberOfFATs]				; Number of FATs
		mul WORD [bpbSectorsPerFAT]				; Multiply by Sectors Per FAT
		mov BYTE [DISK_VARS.SECTORS_TO_READ], al
		
		mov ax, [bpbReservedSectors]			; Read sectors immediatley after the reserved sectors
		mov [DISK_VARS.LBA], ax
		
		call Disk.LBA_To_CHS
		
		call Disk.ReadSectors
		ret
	
	 .Cluster_To_LBA:							; LBA = (Cluster - 2 ) * SectorsPerCluster	???
		mov ax, WORD [DISK_VARS.CLUSTER]
		add ax, [DISK_VARS.RD_START]
		add ax, [DISK_VARS.RD_SIZE]
		sub ax, 2                          		; Subtract 2 from cluster number
		mov cx, 0
		mov cl, BYTE [bpbSectorsPerCluster]     ; Get sectors per cluster
		mul cx                                  ; Multiply
		mov [DISK_VARS.LBA], ax
		ret
		
	.LBA_To_CHS:
		;Absolute Sector 	= 	(LBA  %  SectorsPerTrack) + 1
		;Absolute Head   	= 	(LBA  /  SectorsPerTrack) % Heads
		;Absolute Cylinder 	= 	 LBA  / (SectorsPerTrack  * Heads)
		
		mov dx, 0
		mov ax, WORD [DISK_VARS.LBA]
		div WORD [bpbSectorsPerTrack]			; (LBA % SectorsPerTrack)
		inc dx									; + 1
		mov BYTE [DISK_VARS.SECTOR], dl
		
		mov dx, 0
		mov ax, WORD [DISK_VARS.LBA]
		div WORD [bpbSectorsPerTrack]			; (LBA / SectorsPerTrack)
		mov dx, 0
		div WORD [bpbHeadsPerCylinder]			; % Heads
		mov BYTE [DISK_VARS.HEAD], dl
		
		mov dx, 0
		mov ax, WORD [bpbSectorsPerTrack]
		mul WORD [bpbHeadsPerCylinder]			; (SectorsPerTrack * Heads)
		mov cx, ax
		mov ax, WORD [DISK_VARS.LBA]			; LBA / ()
		div cx
		mov BYTE [DISK_VARS.CYLINDER], al
		
		ret
		
	.Load_File:
		.start:
			mov al, [bpbSectorsPerCluster]
			mov [DISK_VARS.SECTORS_TO_READ], al
			
			call Disk.Cluster_To_LBA					; Convert Cluster to LBA
			call Disk.LBA_To_CHS						; And then to CHS
			call Disk.ReadSectors
			
			mov     ax, WORD [DISK_VARS.CLUSTER]        ; Identify current cluster
			mov     cx, ax                              ; Copy current cluster
			mov     dx, ax                              ; Copy current cluster
			shr     dx, 0x0001                          ; Divide by two
			add     cx, dx                              ; Sum for (3/2)
			mov     bx, 0x0200                          ; Location of FAT in memory
			add     bx, cx                              ; Index into FAT
			mov     dx, WORD [bx]                       ; Read two bytes from FAT
			test    ax, 0x0001
			jnz     .odd
			jmp .even
			
		.odd:
			shr     dx, 0x0004                          ; Take high twelve bits
			jmp .get_cluster
		
		.even:
			and     dx, 0x0FFF               			; Take low twelve bits
			jmp .get_cluster
		
		.get_cluster:
			mov     WORD [DISK_VARS.CLUSTER], dx                  ; store new cluster
			cmp     dx, 0x0FF0                          ; test for end of file
			jb      start
			ret
		
	.Get_File:
		push ax
		push bx
		push si
		
		mov ax, 0x07C0
		mov	ds, ax
		mov	es, ax
		
		call Disk.Load_RD							; Load Root Directory
		pop si
		call Disk.Search_For_File					; Find Second Stage
		call Disk.Load_FAT							; Load FAT
	
		pop bx
		mov [DISK_VARS.MEM_SEGMENT], bx
		pop ax
		mov [DISK_VARS.MEM_OFFSET], ax
	
		call Disk.Load_File
		ret
		
	.Error:
		mov ah, 0x0e
		mov al, "E"
		int 0x10
		cli
		hlt
		
; ----- Variables -----
DISK_VARS:
	;.CYLINDER:
		;db 0
	;.HEAD:
		;db 0
	;.DISK:
		;db 0
	;.SECTOR:
		;db 0
		
	DISK_VARS.CYLINDER EQU 0x0400			; To save space
	DISK_VARS.HEAD EQU 0x0401
	DISK_VARS.DISK EQU 0x0402
	DISK_VARS.SECTOR EQU 0x0403
	
	.SECTORS_TO_READ:
		db 0
	.MEM_SEGMENT:
		dw 0x07E0
	.MEM_OFFSET:
		dw 0x0000
	.FILENAME:
		db "SECTOR2 SYS", 0
		
	.CLUSTER:								; That trick doesn't work here for some reason - ???
		dw 0
	.LBA:
		dw 0
	.RD_START:
		dw 0
		
	;DISK_VARS.CLUSTER EQU 0x0404
	;DISK_VARS.LBA EQU 0x0406
	;DISK_VARS.RD_START EQU 0x0408
	;DISK_VARS.RD_SIZE EQU 0x040A
	
	; 0x0000 - 0x01FF	-	Bootloader
	; 0x0200 - 0x03FF	-	FAT / RD
	; 0x0400 - 0x05FF	-	VARs
	
times 510 - ($-$$) db 0
.RD_SIZE:	;1337 H4X0R to save space
dw 0xAA55