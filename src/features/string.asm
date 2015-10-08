; ---------------------------------------------------------------
; os_string_length -- Return length of a string
; IN: AX = string location
; OUT: AX = length (other regs preserved)

os_string_length:
	pusha
	
	mov bx, ax						; Move location of string to BX
	
	mov cx, 0						; Counter
	
.more:
	cmp BYTE [bx], 0				; Zero (end of string) yet?
	je .done
	inc bx							; If not, keep adding
	inc cx
	jmp .more
	
	
.done:
	mov WORD [.tmp_counter], cx		; Store count before restoring other registers
	popa
	
	mov ax, [.tmp_counter]			; Put count back into AX before returing
	ret
	
	
	.tmp_counter		dw 0
	
	
; ---------------------------------------------------------------
; os_string_reverse -- Reverse the caracters in a string
; IN: SI = string location

os_string_reverse:
	pusha
	
	cmp BYTE [si], 0				; Don't attempt to reverse empty string
	je .end
	
	mov ax, si
	call os_string_length
	
	mov di, si
	add di, ax
	dec di							; DI now points to last char in string
	
.loop:
	mov BYTE al, [si]				; Swap bytes
	mov BYTE bl, [di]
	
	mov BYTE [si], bl
	mov BYTE [di], al
	
	inc si							; Move towards string centre
	dec di
	
	cmp di, si						; Both reached the centre?
	ja .loop
	
.end:
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_string_uppercase -- Convert zero-terminated string to upper case
; IN/OUT: AX = string location

os_string_uppercase:
	pusha
	
	mov si, ax						; Use SI to access string
	
.more:
	cmp BYTE [si], 0				; Zero-termination of string
	je .done						; If so, quit
	
	cmp BYTE [si], 'a'				; In the lower case A to Z range?
	jb .noatoz
	cmp BYTE [si], 'z'
	ja .noatoz
	
	sub BYTE [si], 20h				; If so, convert input char to upper case
	inc si
	jmp .more
	
.noatoz:
	inc si
	jmp .more
	
.done:
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_string_lowercase -- Convert zero-terminated string to lower case
; IN/OUT: AX = string location

os_string_lowercase:
	pusha
	
	mov si, ax						; Use SI to access string
	
.more:
	cmp BYTE [si], 0				; Zero-termination of string?
	je .done						; If so, quit
	
	cmp BYTE [si], 'A'				; In the upper case A to Z range?
	jb .noatoz
	cmp BYTE [si], 'Z'
	ja .noatoz
	
	add BYTE [si], 20h				; If so, convert input char to lower case
	
	inc si
	jmp .more
	
.noatoz:
	inc si
	jmp .more
	
.done:
	popa
	ret
	
	
; ---------------------------------------------------------------
; os_string_compare -- See if two string match
; IN: SI = string one, DI = string two
; OUT: carry set if same, clear if different

os_string_compare:
	pusha

.more:
	mov al, [si]					; Retrieve string contents
	mov bl, [di]
	
	cmp al, bl						; Compare characters at current location
	jne .not_same
	
	cmp al, 0						; End of first string? Must also be end of second
	je .terminated
	
	inc si
	inc di
	jmp .more
	
	
.not_same:							; If unequal length with same beginning, the byte
	popa							; comparison fails at shortest string terminator
	clc								; Clear carry flag
	ret
	
	
.terminated:						; Both string terminated at the same position
	popa
	stc								; Set carry flag
	ret
	

; ---------------------------------------------------------------
; os_string_to_int -- Convert decimal string to integer value
; IN: SI = string location (max 5 chars, up to '65536')
; OUT: AX = number

os_string_to_int:
	pusha
	
	mov ax, si						; First, get length of string
	call os_string_length
	
	add si, ax						; Work from rightmost char in string
	dec si
	
	mov cx, ax						; Use string length as counter
	
	mov bx, 0						; BX will be the final number
	mov ax, 0
	
	
	; As we move left in the string, each char is a bigger multiple. The
	; right-most character is a multiple of 1, then next (a char to the
	; left) a multiple of 10, then 100, then 1,000, and the final (and
	; leftmost char) in a five-char number would be a multiple of 10,000
	
	mov word [.multiplier], 1		; Start with multiples of 1
	
.loop:
	mov ax, 0
	mov byte al, [si]				; Get character
	sub al, 48						; Convert from ASCII to real number
	
	mul word [.multiplier]			; Multiply by our multiplier
	
	add bx, ax						; Add it to BX
	
	push ax							; Multiply our multiplier by 10 for next char
	mov word ax, [.multiplier]
	mov dx, 10
	mul dx
	mov word [.multiplier], ax
	pop ax
	
	dec cx							; Any more chars?
	cmp cx, 0
	je .finish
	dec si							; Move back a char in the string
	jmp .loop
	
.finish:
	mov word [.tmp], bx
	popa
	mov word ax, [.tmp]
	
	ret
	
	
	.multiplier	dw 0
	.tmp		dw 0
	
	
; ---------------------------------------------------------------
; os_int_to_string -- Convert unsigned integer to string
; IN: AX = signed int
; OUT: AX = string location

os_int_to_string:
	pusha
	
	mov cx, 0
	mov bx, 10						; Set BX 10, for division and mod
	mov di, .t						; Get out pointer ready
	
.push:
	mov dx, 0
	div bx							; Remainder in DX, quotient in AX
	inc cx							; Increase pop loop counter
	push dx							; Push remainder, so as to reverse order when popping
	test ax, ax						; Is quotient zero?
	jnz .push						; If not, loop again
.pop:
	pop dx
	add dl, '0'						; And save them in the string, increasing the pointer each time
	mov [di], dl
	inc di
	dec cx
	jnz .pop
	
	mov byte [di], 0				; Zero-terminate string
	
	popa
	mov ax, .t						; Return location of string
	ret
	
	
	.t times 7 db 0
	
	
; ---------------------------------------------------------------
; os_get_time_string -- Get current time in a string (eg '10:25')
; IN/OUT: BX = string location

os_get_time_string:
	pusha
	
	mov di, bx						; Location to place time string
	
	clc								; For buggy BIOSes
	mov ah, 2						; Get time data from BIOS in BCD format
	int 1Ah
	jnc .read
	
	clc
	mov ah, 2						; BIOS was updating (~1 in 500 chance), so try again
	int 1Ah
	
.read:
	mov al, ch						; Convert hours to integer for AM/PM test
	call os_bcd_to_int
	mov dx, ax						; Save
	
	mov al, ch						; Hour
	shr al, 4						; Tens digit - move higher BCD number into lower bits
	and ch, 0Fh						; Ones digit
	
	call .add_digit	
	mov al, ch
	call .add_digit
	
	call .add_colon
	
.minutes:
	mov al, cl						; Minute
	shr al, 4						; Tens digit - move higher BCD number into lower bits
	and cl, 0Fh						; Ones digit
	call .add_digit
	mov al, cl
	call .add_digit
	
	mov al, 0
	stosb
	
	popa
	ret
	
	
.add_digit:
	add al, '0'						; Convert to ASCII
	stosb							; Put into string buffer
	ret
	
.add_colon:
	mov al, ':'
	stosb
	ret
	
	
	.hours_string		db 'hours', 0