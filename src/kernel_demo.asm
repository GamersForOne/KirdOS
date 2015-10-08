	BITS 16
	
	%DEFINE KIRDOS_VER '0.0.1_D'				; OS version number
	
	
	
	disk_buffer	equ 24576
	
	
os_call_vectors:
	jmp os_main					; 0000h -- Called from bootloader
	jmp os_print_string			; 0003h
	jmp os_clear_screen			; 0006h
	jmp os_move_cursor			; 0009h
	jmp os_print_newline		; 000Ch
	jmp os_string_length		; 000Fh
	jmp os_string_uppercase		; 0012h
	jmp os_string_lowercase		; 0015h
	jmp os_string_compare		; 0018h
	jmp os_seed_random			; 001Bh
	jmp os_get_random			; 001Eh
	jmp os_pause				; 0021h
	jmp os_wait_for_key			; 0024h
	jmp os_get_line				; 0027h
	
	
	
; ---------------------------------------------------------------
; START OF KERNEL CODE

os_main:
	cli							; Clear interrupts
	mov ax, 0
	mov ss, ax					; Set stack segment and pointer
	mov sp, 0FFFFh
	sti							; Restore interrupts
	
	cld
	
	mov ax, 2000h				; Sets segments to match kernel location in RAM
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
	movzx dx, dh				; Maximum head number
	add dx, 1					; Head number start at 0 - add 1 for total
	mov [Sides], dx
	
no_change:
	mov ax, 1003h				; Set text output with certain attributes
	mov bx, 0					; to be bright, and not blinking
	int 10h
	
	call os_seed_random
	
	jmp main_loop
	
	
main_loop:
	call os_clear_screen
	
	call os_draw_screen
	
	call os_wait_for_key
	
	cmp ax, 0
	jg .check_key