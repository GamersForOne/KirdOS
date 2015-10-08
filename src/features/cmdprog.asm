; ===============================================================
; CmdProg -- Programming language interpreter for KirdOS
;
; CMDPROG CODE INTERPRETER (0.1)
; ===============================================================

; ---------------------------------------------------------------
; The CmdProg interpreter execution starts here
; Program must end with 4 zero-terminators

os_run_cmdprog:
	mov WORD [prog], 0x8000
	mov WORD [prog_end], 0x8000
	mov ax, WORD [prog_end]
	mov cx, bx
.loop1:
	inc ax
	xchg cx, dx
	mov cx, 4
	mov si, ax
	mov di, term_prog
	rep cmpsb
	je .loopdone
	xchg cx, dx
	loop .loop1
	jmp os_cmdprog_invalid
	
.loopdone:
	xchg cx, dx
	mov 
	
	
; ===============================================================
; DATA SECTION
	
	prog			dw 0 			; Pointer to current location in CmdProg code
	prog_end		dw 0			; Pointer to final byte of CmdProg code
	
	term_prog		times 4 db 0	; Program terminator value
	
vars_loc:
	variables		times 26 dw 0		; Storage space for variables A to Z
	variable_types	times 26 db 0		; Storage space for variables A to Z types
	
	cmd_clear		db "CLEAR", 0
	cmd_print		db "PRINT", 0
	cmd_write		db "WRITE", 0
	cmd_if			db "IF", 0
	cmd_exit		db "EXIT", 0
	cmd_pause		db "PAUSE", 0
	cmd_set			db "SET", 0
	cmd_unset		db "UNSET", 0
	cmd_input		db "INPUT", 0
	
	keyw_then		db "THEN", 0
	keyw_and		db "AND", 0