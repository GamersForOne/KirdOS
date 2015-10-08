; ---------------------------------------------------------------
; os_wait_for_key -- Waits for keypress and returns key
; IN: Nothing; OUT: AX = key pressed, other regs preserved

os_wait_for_key:
	pusha
	
	mov ax, 0
	mov ah, 10h						; BIOS call to wait for key
	int 16h
	
	call keybd_log_key				; Log the key in the keylogger
	mov [.tmp_buf], ax				; Store resulting keypress
	
	popa							; But restore all other regs
	mov ax, [.tmp_buf]
	ret
	
	
	.tmp_buf		dw 0
	
	
; ---------------------------------------------------------------
; os_check_for_key -- Scans keyboard for input, but doesn't wait
; IN: Nothing; OUT: AX = 0 if no key press, otherwise scan code

os_check_for_key:
	pusha
	
	mov ax, 0
	mov ah, 1						; BIOS call to check for key
	int 16h
	
	jz .nokey						; If no key, skip to end
	
	mov ax, 0						; Otherwise get it from buffer
	int 16h
	
	call keybd_log_key				; Log the key in the keylogger
	mov [.tmp_buf], ax				; Store resulting keypress
	
	popa							; But restore all other regs
	mov ax, [.tmp_buf]
	ret
	
.nokey:
	popa
	mov ax, 0						; Zero result if no key pressed
	ret
	
	
	.tmp_buf		dw 0
	
	
; ---------------------------------------------------------------
; os_get_line -- Reads input until user presses return
; IN/OUT: SI = Location of 64 byte input string

os_get_line:
	xor cl, cl
	
.loop:
	mov ah, 0
	int 0x16
	
	cmp al, 0x08
	je .backspace
	
	cmp al, 0x0D
	je .done
	
	cmp cl, 0x3F
	je .loop
	
	mov ah, 0x0E
	int 0x10
	
	stosb
	inc cl
	jmp .loop
	
.backspace:
	cmp cl, 0
	je .loop
	
	dec di
	mov BYTE [di], 0
	dec cl
	
	mov ah, 0x0E
	mov al, 0x08
	int 0x10
	
	mov al, ' '
	int 0x10
	
	mov al, 0x08
	int 0x10
	
	jmp .loop
	
.done:
	mov al, 0
	stosb
	
	mov ah, 0x0E
	mov al, 0x0D
	int 0x10
	mov al, 0x0A
	int 0x10
	
	ret
	
	.tmp_buf	times 64 db 0
	
	
; ===============================================================
; SYSTEM FUNCTION - NOT ACCESSIBLE FOR USER
; ===============================================================

; ---------------------------------------------------------------
; keybd_log_key -- logs a key for later usage
; IN: AX = key to log

keybd_log_key:
	pusha
	
	mov bx, 126
	mov si, keyboard_key_log
.loop:
	mov dx, [si+bx]
	mov [si+bx+1], dx
	
	cmp bx, 0
	je .done
	
	dec bx
	jmp .loop
.done:
	mov [si], ax
	popa
	ret
	
	
; ---------------------------------------------------------------
; keybd_log_get -- gets the log of keys
; IN: Nothing. OUT: DI = address to key_array
	
keybd_log_get:
	mov si, keyboard_key_log
	ret
	
keyboard_key_log			times 129 db 0