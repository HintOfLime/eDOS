;+---------------------------------+
;|  SECTOR 1 - Primary Bootloader  |
;+---------------------------------+

; TODO:
;	Add repeats to ReadSectors
;	Setup Get_File as an interrupt									Sort of, can just call 0x07C0:0x0000
; 	Fix Search_For_File (only works if SI is [FILENAME] - WAT!)		DONE
;	Get variables under control
; 	Make room for stack setup
; 	General Cleanup
;	Fix overwriting issue

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
	;mov ax, 0x0000										; Not enough room to set up stack so have to hope it is in an OK area
	;mov ss, ax
	;mov sp, 0xFFFF
	sti
	
	mov [DISK_VARS.DISK], dl							; Set disk
	
	mov ax, Disk.Get_File								; Set up so a call to 0x0000:7C00 will go to Get_File
	mov [0x0001], ax
	
	;mov ax, 0x0000																											-+
	;mov ds, ax																												 |
	;																														 |
	;mov ax, Disk.Get_File																									 |
	;mov [0x0080], ax									; INT 20h is at 0x0000 + (0x0004 * 0x0020)		=		0x0080h			 	 +- Setup as interrupt
	;																														 |
	;mov [0x0082], ds																										 |
	;																														 |
	;mov ds, ax																												-+
	
	mov si, DISK_VARS.FILENAME
	mov ax, 0x0000										; Offset:	0x0000
	mov bx, 0x0A00										; Segment:	0x0A00
	call 0x07C0:Disk.Get_File
	
	jmp 0x0A00:0x0000									; Jump to Second Stage

; ----- Routines -----
Disk:
	.Reset:
		mov ah, 0
		mov dl, [DISK_VARS.DISK]
		int 0x13
		;jc .Error
		ret

	.ReadSectors:
		mov ah, 0x02 									; BIOS read sector function
		mov al, [DISK_VARS.SECTORS_TO_READ]				; Select number of segments
		push ax
		mov ch, [DISK_VARS.CYLINDER] 					; Select cylinder
		mov cl, [DISK_VARS.SECTOR] 						; Select sector to read
		mov dh, [DISK_VARS.HEAD] 						; Select head
		mov dl, [DISK_VARS.DISK]						; Select disk
		mov bx, [DISK_VARS.MEM_OFFSET]					; Select memory offset
		push es
		push bx
		mov bx, [DISK_VARS.MEM_SEGMENT]					; Select memory segment
		mov es, bx
		pop bx
		int 0x13 										; BIOS interrupt
		pop es
		jc .Error 										; Jump if error
		pop dx
		cmp dl, al 										; If AL ( sectors read ) != DL ( sectors expected )
		jne .Error 										; Jump to error
		ret
	
	.Load_RD:
		; Compute size of Root Directory
		mov ax, 32	        							; ( 32 byte directory entry
		mul WORD [bpbRootEntries]  						;   * Number of root entrys )
		mov dx, 0
		div WORD [bpbBytesPerSector] 					; / sectors used by root directory
		mov [DISK_VARS.SECTORS_TO_READ], al				; Set as parameter
		mov [DISK_VARS.RD_START], ax
		
		; Compute location of Root Directory
		mov al, [bpbNumberOfFATs]  						; Get number of FATs (Usually 2)
		mul WORD [bpbSectorsPerFAT]  					; Number of FATs * sectors per FAT
		add ax, WORD [bpbReservedSectors] 				; Add reserved sectors
		mov [DISK_VARS.LBA], ax							; Set as parameter
		mov [DISK_VARS.RD_SIZE], ax
		call Disk.LBA_To_CHS							; Convert to CHS for disk read
		
		mov ax, 0x0000
		mov [DISK_VARS.MEM_OFFSET], ax
		mov ax, 0x07E0
		mov [DISK_VARS.MEM_SEGMENT], ax
		
		call Disk.Reset									; Reset disk
		call Disk.ReadSectors							; Load root directory
	
		ret
			
	.Search_For_File:
		mov cx, [bpbRootEntries]
		mov di, 0x0200
		mov si, DISK_VARS.FILENAME
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
			;mov ah, 0x0e
			;mov al, "E"
			;int 0x10
			jmp Disk.Error
			.Done:
			mov ax, WORD [di + 26]
			mov WORD [DISK_VARS.CLUSTER], ax
			ret
	
	.Load_FAT:
		mov ax, 0
		mov al, [bpbNumberOfFATs]						; Number of FATs
		mul WORD [bpbSectorsPerFAT]						; Multiply by Sectors Per FAT
		mov BYTE [DISK_VARS.SECTORS_TO_READ], al
		
		mov ax, [bpbReservedSectors]					; Read sectors immediatley after the reserved sectors
		mov [DISK_VARS.LBA], ax
		
		call Disk.LBA_To_CHS
		
		;mov ax, 0x0000
		;mov [DISK_VARS.MEM_OFFSET], ax
		;mov ax, 0x07E0
		;mov [DISK_VARS.MEM_SEGMENT], ax
		
		call Disk.ReadSectors
		ret
	
	 .Cluster_To_LBA:									; LBA = (Cluster - 2 ) * SectorsPerCluster	???
		mov ax, WORD [DISK_VARS.CLUSTER]
		add ax, [DISK_VARS.RD_START]
		add ax, [DISK_VARS.RD_SIZE]
		sub ax, 2                          				; Subtract 2 from cluster number
		mov cx, 0
		mov cl, BYTE [bpbSectorsPerCluster]     		; Get sectors per cluster
		mul cx                                  		; Multiply
		mov [DISK_VARS.LBA], ax
		ret
		
	.LBA_To_CHS:
		; Absolute Sector 	= 	(LBA  %  SectorsPerTrack) + 1
		; Absolute Head   	= 	(LBA  /  SectorsPerTrack) % Heads
		; Absolute Cylinder 	= 	 LBA  / (SectorsPerTrack  * Heads)
		
		mov dx, 0
		mov ax, WORD [DISK_VARS.LBA]
		div WORD [bpbSectorsPerTrack]					; (LBA % SectorsPerTrack)
		inc dx											; + 1
		mov BYTE [DISK_VARS.SECTOR], dl
		
		mov dx, 0
		mov ax, WORD [DISK_VARS.LBA]
		div WORD [bpbSectorsPerTrack]					; (LBA / SectorsPerTrack)
		mov dx, 0
		div WORD [bpbHeadsPerCylinder]					; % Heads
		mov BYTE [DISK_VARS.HEAD], dl
		
		mov dx, 0
		mov ax, WORD [bpbSectorsPerTrack]
		mul WORD [bpbHeadsPerCylinder]					; (SectorsPerTrack * Heads)
		mov cx, ax
		mov ax, WORD [DISK_VARS.LBA]					; LBA / ()
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
			mov     WORD [DISK_VARS.CLUSTER], dx       	; Store new cluster
			cmp     dx, 0x0FF0                          ; Test for end of file
			jb      start
			ret
		
	.Get_File:
		push es
		push ds
		push ax
		push bx
		
		mov ax, 0x07C0									; Set ES to current segment
		mov	es, ax										; So that
		mov di, DISK_VARS.FILENAME						; ES:DI points to disk string variable   &   DS:SI already points to far filename string

		mov cx, 11										; Set to 11 byte length
		rep movsb										; Copy string accross
		
		mov	ds, ax										; Now also set DS to current segment
		
		call Disk.Load_RD								; Load Root Directory
		
		call Disk.Search_For_File						; Find File
		call Disk.Load_FAT								; Load FAT
		
		pop bx
		mov [DISK_VARS.MEM_SEGMENT], bx
		pop ax
		mov [DISK_VARS.MEM_OFFSET], ax
		
		call Disk.Load_File
		
		pop ds
		pop es
		xchg bx, bx
		retf											; All works, returns fine, file loads but all bytes are now 0x00 so we may have overwritten ourselves
		
	.Error:
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
	;.SECTORS_TO_READ:
		;db 0
		
	DISK_VARS.CYLINDER EQU 0x0400						; To save space
	DISK_VARS.HEAD EQU 0x0401
	DISK_VARS.DISK EQU 0x0402
	DISK_VARS.SECTOR EQU 0x0403
	DISK_VARS.SECTORS_TO_READ EQU 0x0404
	
	.MEM_SEGMENT:
		dw 0x07C0
	.MEM_OFFSET:
		dw 0x0200
	.FILENAME:
		db "SECTOR2 SYS", 0
	
	.CLUSTER:											; That trick doesn't work here for some reason - ???
		dw 0
	.LBA:
		dw 0
	.RD_START:
		dw 0
	
times 510 - ($-$$) db 0
.RD_SIZE:												;So have to use 1337 H4X0R to save space
dw 0xAA55