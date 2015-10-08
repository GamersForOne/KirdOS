; ---------------------------------------------------------------
; Hello World program

	BITS 16
	%INCLUDE "kirdosdev.inc"
	ORG 8000h
	
; ---------------------------------------------------------------
; Start

jmp main

; ---------------------------------------------------------------
; Variables

hellow_str					db "Hello World and welcome to first program", 13, 10, 0
exit_string					db "Press any key to exit Hello World...", 13, 10, 0
enter_name					db "What's your name? ", 0
hello_name					db "Hello, ", 0

buffer						times 64 db 0

; ---------------------------------------------------------------
; main

main:
	mov si, hellow_str
	call os_print_string
	mov si, enter_name
	call os_print_string
	mov si, buffer
	call os_get_line
	mov BYTE [si], 0
	push si
	mov si, hello_name
	call os_print_string
	pop si
	mov si, buffer
	call os_print_string
	call os_print_newline
	mov si, exit_string
	call os_print_string
	call os_wait_for_key
	ret