;+---------------------------------+
;| SECTOR 2 - Secondary Bootloader |
;+---------------------------------+

[bits 16]
[org 0x0A00:0x0000]

; ----- Main -----

;mov ax, 0x0A00
;mov	ds, ax
;mov	es, ax

;mov si, TestString
;call Print

;cli
;hlt

; ----- Data -----
;TestString:
;db "Hello World!", 0

db 0xDE, 0xAD