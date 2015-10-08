; ---------------------------------------------------------------
; os_print_string -- Displays text
; IN: SI = message location (zero-terminated string)
; OUT: Nothing (registers preserved)

os_print_string:
	pusha
	
	mov ah, 0Eh						; int 10h teletype function
	
.repeat:
	lodsb							; Get char from string
	cmp al, 0
	je .done						; If char is zero, end of string
	
	int 10h							; Otherwise, print it
	jmp .repeat						; And move on to the next char
	
.done:
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_clear_screen -- Clears the screen to background
; IN/OUT: Nothing (registers preserved)

os_clear_screen:
	pusha
	
	mov dx, 0						; Position cursor at top-left
	call os_move_cursor
	
	mov ah, 6						; Scroll full-screen
	mov al, 0						; Normal white on black
	mov bh, 7						;
	mov cx, 0						; Top-left
	mov dh, 24						; Bottom-right
	mov dl, 79
	int 10h
	
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_move_cursor -- Moves cursor in text mode
; IN: DH, DL = row, column; OUT: Nothing (registers preserved)

os_move_cursor:
	pusha
	
	mov bh, 0
	mov ah, 2
	int 10h							; BIOS interrupt to move cursor
	
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_get_cursor_pos -- Return position of text cursor
; OUT: DH, DL = row, column

os_get_cursor_pos:
	pusha
	
	mov bh, 0
	mov ah, 3
	int 10h							; BIOS interrupt to get cursor position
	mov [.tmp], dx
	popa
	mov dx, [.tmp]
	ret
	
	
	.tmp dw 0
	
	
; ---------------------------------------------------------------
; os_show_cursor -- Turns on cursor in text mode
; IN/OUT: Nothing

os_show_cursor:
	pusha
	
	mov ch, 6
	mov cl, 7
	mov ah, 1 
	mov al, 3
	int 10h
	
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_hide_cursor -- Turns off cursor in text mode
; IN/OUT: Nothing

os_hide_cursor:
	pusha
	
	mov ch, 32
	mov ah, 1
	mov al, 3							; Must be video mode for buggy BIOSes!
	int 10h
	
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_print_newline -- Reset cursor to start of next line
; IN/OUT: Nothing (registers preserved)

os_print_newline:
	pusha
	
	mov ah, 0Eh							; BIOS output char code
	
	mov al, 13
	int 10h
	mov al, 10
	int 10h
	
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_draw_horiz_line -- Draw a horizontal line on the screen
; IN: AX = line type (1 for double (-), otherwise single (=))
; OUT: Nothing (registers preserved)

os_print_horiz_line:
	pusha
	
	mov cx, ax							; Store line type param
	mov al, 196							; Default is single-line code
	
	cmp cx, 1							; Was double-line specified in AX?
	jne .ready
	mov al, 205							; If so, here's the code
	
.ready:
	mov cx, 0							; Counter
	mov ah, 0Eh							; BIOS output char routine
	
.restart:
	int 10h
	inc cx
	cmp cx, 80							; Drawn 80 chars yet?
	je .done
	jmp .restart
	
.done:
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_draw_block == render block of specified color
; IN: BL/DL/DH/SI/DI = color/start X pos/start Y pos/width/finish Y pos

os_draw_block:
	pusha
	
.more:
	call os_move_cursor					; Move to block starting position
	
	mov ah, 09h							; Draw color sections
	mov bh, 0
	mov cx, si
	mov al, ' '
	int 10h
	
	inc dh								; Get ready for next line
	
	mov ax, 0
	mov al, dh							; Get current Y position into DL
	cmp ax, di							; Reached finishing point (DI)?
	jne .more							; If not, keep drawing
	
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_draw_background -- Draws the default background of KirdOS
; IN: Nothing; OUT: AX = String containing current time

os_draw_background:
	pusha
	
	call os_clear_screen
	
	; Draw default frame
	
	
	mov bl, 80h
	mov dl, 0
	mov dh, 1
	mov si, 80
	mov di, 2
	call os_draw_block
	mov bl, 2Fh
	mov dl, 0
	mov dh, 0
	mov si, 80
	mov di, 1
	call os_draw_block
	mov bl, 70h
	mov dl, 0
	mov dh, 2
	mov si, 80
	mov di, 25
	call os_draw_block
	
	; Draw OS and Version
	
	mov dh, 0
	mov dl, 0
	call os_move_cursor
	mov bl, 2Fh
	mov si, os_msg
	call os_print_string
	mov ax, os_version_msg
	call os_string_length
	mov dx, 79
	sub dx, ax
	call os_move_cursor
	mov bl, 2Fh
	mov si, os_version_msg
	call os_print_string
	
	; Draw Clock
	
	mov bx, .time
	call os_get_time_string
	mov ax, bx
	call os_string_length
	mov dx, 79
	sub dx, ax
	mov dh, 1
	call os_move_cursor
	mov si, .time
	mov bl, 70h
	call os_print_string
	
	popa
	mov ax, .time
	ret
	
	.time		times 10 db 0
	

; ---------------------------------------------------------------
; os_draw_menu -- Draws a menu for KirdOS
; IN/OUT: Nothing

os_draw_menu:
	pusha
	
	mov dh, 1
	mov dl, 0
	call os_move_cursor
	mov bl, 80h
	mov si, .menu_1
	call os_print_string
	mov si, .space
	call os_print_string
	mov si, .menu_2
	call os_print_string
	mov si, .space
	call os_print_string
	mov si, .menu_3
	call os_print_string
	
	popa
	ret
	
	.menu_1			db "1.APPS", 0
	.menu_2			db "2.TERM", 0
	.menu_3			db "3.SHUTDOWN", 0
	.space			db ' ', 0
	
	
; ---------------------------------------------------------------
; os_draw_windows -- Draws the windows for KirdOS
; IN: SI = Message; OUT: Nothing

os_draw_windows:
	pusha
	
	; Draw welcome
	
	mov dl, 80
	mov ax, .welcome_msg
	call os_string_length
	sub dl, al
	mov cl, dl
.loop1:
	cmp cl, 1
	jle .loop1end
	dec dl
	sub cl, 2
	jmp .loop1
.loop1end:
	mov dh, 4
	call os_move_cursor
	mov bl, 70h
	mov si, .welcome_msg
	call os_print_string
	
	mov dl, 80
	mov ax, .welcome_msg_by
	call os_string_length
	sub dl, al
	mov cl, dl
.loop2:
	cmp cl, 1
	jle .loop2end
	dec dl
	sub cl, 2
	jmp .loop2
.loop2end:
	mov dh, 5
	call os_move_cursor
	mov bl, 70h
	mov si, .welcome_msg_by
	call os_print_string
	
	; Draw message
	
	mov dh, 7
	mov dl, 1
	mov si, word [win_msg]
	call os_print_string
	
	
	popa
	ret
	
	.welcome_msg			db "Welcome to KirdOS", 0
	.welcome_msg_by			db "Written by Kirdow in Assembly", 0
	
; ---------------------------------------------------------------
; os_draw_screen -- Main renderer for KirdOS
; IN: Nothing; OUT: AX = String containing current time

os_draw_screen:
	pusha
	
	call os_draw_background
	call os_draw_menu
	call os_draw_windows
	
	mov dh, 24
	mov dl, 0
	call os_move_cursor
	
	mov word [.time], ax
	popa
	mov ax, word [.time]
	ret
	
	.time			dw 0
	
	
; ---------------------------------------------------------------
; os_list_dialog -- Shows a list dialog to the user
; IN: AX = Question string, SI = Comma separated string of values
; OUT: AX = String containing value

os_list_dialog:
	