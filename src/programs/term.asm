	
	BITS 16
	%INCLUDE "kirdosdev.inc"
	ORG 8000h
	
	jmp main
	
	prompt				db "> ", 0
	terminal			db "terminal", 0
	
	buffer				times 64 db 0
	
	cmd_exit			db "exit", 0
	
	unknowncmd			db "Unknown command, currently only command: exit", 13, 10, 0
	
	any_key_msg			db "Press any key to exit...", 0
	
main:
	
	mov si, terminal
	call os_print_string
	mov si, prompt
	call os_print_string
	
	mov si, buffer
	call os_get_line
	mov si, buffer
	cmp byte [si], 0
	je main
	
	mov si, buffer
	mov di, cmd_exit
	call os_string_compare
	jc .cmd_run_exit
	
	mov si, unknowncmd
	call os_print_string
	jmp main
	
.cmd_run_exit:
	mov si, any_key_msg
	call os_print_string
	call os_wait_for_key
	call os_print_newline
	ret