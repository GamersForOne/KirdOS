	BITS 16
	
	%DEFINE KIRDOS_VER '0.2.0.1'		; OS version number
	
	
	
	disk_buffer	equ 24576
	

os_call_vectors:
	jmp os_main					; 0000h -- Called from bootloader
	jmp os_print_string			; 0003h
	jmp os_clear_screen			; 0006h
	jmp os_move_cursor			; 0009h
	jmp os_get_cursor_pos		; 000Ch
	jmp os_show_cursor			; 000Fh
	jmp os_hide_cursor			; 0012h
	jmp os_print_newline		; 0015h
	jmp os_get_file_list		; 0018h
	jmp os_string_length		; 001Bh
	jmp os_string_reverse		; 001Eh
	jmp os_string_uppercase		; 0021h
	jmp os_string_lowercase		; 0024h
	jmp os_string_compare		; 0027h
	jmp os_seed_random			; 002Ah
	jmp os_get_random			; 002Dh
	jmp os_pause				; 0030h
	jmp os_fatal_error			; 0033h
	jmp os_wait_for_key			; 0036h
	jmp os_check_for_key		; 0039h
	jmp os_get_line				; 003Ch
	
	
	
; ---------------------------------------------------------------
; START OF KERNEL CODE

os_main:
	cli				; Clear interrupts
	mov ax, 0
	mov ss, ax		; Set stack segment and pointer
	mov sp, 0FFFFh
	sti				; Restore interrupts
	
	cld				
	
	mov ax, 2000h			; Sets segments to match kernel location in RAM
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	
	cmp dl, 0
	je no_change
	mov [bootdev], dl			; Save boot device number
	push es
	mov ah, 8					; Get drive parameters
	int 13h
	pop es
	and cx, 3Fh					; Maximum sector number
	mov [SecsPerTrack], cx		; Sectors number start at 1
	movzx dx, dh				; Maximum head humber
	add dx, 1					; Head numbers start at 0 - add 1 for total
	mov [Sides], dx
	
no_change:
	mov ax, 1003h				; Set text output with certain attributes
	mov bx, 0					; to be bright, and not blinking
	int 10h
	
	call os_seed_random
	
	mov si, win_msg_none
	mov word [win_msg], si
	
	jmp main_loop
	
	
main_loop:
	call os_clear_screen
	
	call os_draw_screen
	
	call os_wait_for_key
	
	cmp ax, 0
	jg .check_key
	
.main_loop_pause:
	
	mov ax, 5
	call os_pause
	jmp main_loop
	
.check_key:
	cmp al, '1'
	je .cmd_apps
	
	cmp al, '2'
	je .cmd_terminal
	
	cmp al, '3'
	je .cmd_shutdown
	
	mov si, win_msg_none
	mov word [win_msg], si
	jmp .main_loop_pause
	
.cmd_apps:
	mov si, win_msg_apps
	mov word [win_msg], si
	jmp .main_loop_pause
.cmd_terminal:
	mov si, win_msg_term
	mov word [win_msg], si
	jmp .main_loop_pause
.cmd_shutdown:
	mov si, win_msg_shutdown
	mov word [win_msg], si
	jmp .main_loop_pause
	
app_selector:
	popa
	mov si, os_init_msg
	call os_print_string
	call os_print_newline
	mov si, os_version_msg
	call os_print_string
	call os_print_newline
	
	call os_draw_screen
	
	jmp $
	
	
file_selector:
	pusha
	mov word [.filename], 0
	
	mov ax, .buffer				; Get comma-separated list of filenames
	call os_get_file_list
	
	mov si, .files_str
	call os_print_string
	mov si, .buffer
	call os_print_string
	call os_print_newline
	
	mov si, .enter_file
	call os_print_string
	mov si, buffer
	call os_get_line
	mov si, buffer
	mov ax, buffer
	call os_string_length
	call os_int_to_string
	mov si, ax
	call os_print_string
	call os_print_newline
	mov si, buffer
	call os_file_exists
	jnc .not_found
	
	mov si, buffer					; Did the user try to run 'KRNLDR.SYS'?
	mov di, kern_file_name
	call os_string_compare
	jc no_kernel_execute			; Show an error message if so
	
	push si							; Save filename temporarily
	
	mov bx, si
	mov ax, si
	call os_string_length
	mov si, bx
	add si, ax						; SI not points to end of filename...
	
	dec si
	dec si
	dec si							; ...and now to start of extension!
	
	mov di, bin_ext
	mov cx, 3
	rep cmpsb						; Are final 3 chars 'BIN'?
	jne not_bin_extension			; If not, ask again
	
	pop si							; Restore filename
	mov ax, si
	mov cx, 32768					; Where to load the program file
	call os_load_file				; Load filename prnted by AX
	
	jmp execute_bin_program
	
.not_found:
	call os_clear_screen
	mov si, no_file_found
	call os_print_string
	jmp file_selector
	
	
	.filename				times 12 db 0
	.buffer					times 1024 db 0
	.sbuffer				times 64 db 0
	.char_print				db 0
	.files_str				db "Files on disk: ", 0
	.enter_file				db "Execute program: ", 0
	
	
	
execute_bin_program:
	call os_clear_screen		; Clear screen before running
	
	mov ax, 0					; Clear all registers
	mov bx, 0
	mov cx, 0
	mov dx, 0
	mov si, 0
	mov di, 0
	call 32768					; Call the extenral program code
								; Loaded at second 32K segment
								; (program mus end with 'ret')
								
	call os_clear_screen		; When finished, clear screen
	jmp app_selector			; and go back to the program list
	
no_kernel_execute:				; Warn about trying to executring kernel!
	mov si, kernexec_warn_msg
	call os_print_string
	mov si, press_any_key_msg
	call os_print_string
	push ax
	call os_wait_for_key
	pop ax
	
	jmp app_selector
	
not_bin_extension:
	mov si, binonly_msg
	call os_print_string
	mov si, press_any_key_msg
	call os_print_string
	push ax
	call os_wait_for_key
	pop ax
	
	jmp app_selector
	
; ---------------------------------------------------------------
; SYSTEM VARIABLES -- Settings for programs and system calls

	kernexec_warn_msg			db "You cannot execute the kernel", 13, 10, 0
	binonly_msg					db "You can only executre .BIN files", 13, 10, 0
	press_any_key_msg			db "Press any key to continue...", 13, 10, 0
	
	kern_file_name				db 'KRNLDR.SYS', 0
	bin_ext						db 'BIN', 0
	
	no_file_found				db "Program was not found", 13, 10, 0
	
	os_init_msg					db "Welcome to KirdOS", 0
	os_version_msg				db "Version ", KIRDOS_VER, 0
	os_msg						db "KirdOS", 0
	
	test_str					db "Does show up?", 13, 10, 0
	
	win_msg						dw 0
	win_msg_none				db "No Menu Command", 0
	win_msg_apps				db "Menu Apps", 0
	win_msg_term				db "Menu Term", 0
	win_msg_shutdown			db "Menu Shutdown", 0
	
	buffer			   times 64 db 0


; ---------------------------------------------------------------
; FEATURES -- Code to pull into the kernel


	%INCLUDE "features/cli.asm"
	%INCLUDE "features/disk.asm"
	%INCLUDE "features/keyboard.asm"
	%INCLUDE "features/math.asm"
	%INCLUDE "features/misc.asm"
	%INCLUDE "features/screen.asm"
	%INCLUDE "features/string.asm"
	
	
; ===============================================================
; END OF KERNEL
; ===============================================================
	