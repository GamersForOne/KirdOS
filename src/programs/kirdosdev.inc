; ---------------------------------------------------------------
; Include file for KirdOS program development
; ---------------------------------------------------------------

; ---------------------------------------------------------------
; IMPARTANT LOCATIONS

os_main							equ 0000h		; Where the OS code starts

; ---------------------------------------------------------------
; KEYS

%DEFINE KEY_UP		72
%DEFINE KEY_DOWN	80
%DEFINE KEY_LEFT	75
%DEFINE KEY_RIGHT	77

%DEFINE KEY_ESC		27
%DEFINE KEY_ENTER	13


; ---------------------------------------------------------------
; SYSTEM CALLS

; Screen control

os_print_string					equ 0003h	; SI = zero-terminated string location
os_clear_screen					equ 0006h	; (Nothing used)
os_move_cursor					equ 0009h	; DH, DL = row, column
os_get_cursor_pos				equ 000Ch	; OUT: DH = row, DL = column
os_show_cursor					equ 000Fh	; (Nothing used)
os_hide_cursor					equ 0012h	; (Nothing used)
os_print_newline				equ 0015h	; (Nothing used)

; Keyboard control

os_wait_for_key					equ 0036h	; Returns AL = key pressed
os_check_for_key				equ 0039h	; Returns AL = key pressed
os_get_line						equ 003Ch	; IN/OUT: SI = 64 byte buffer input

; String control

os_string_length				equ 001Bh	; AX = string loc, returns AL = length
os_string_reverse				equ 001Eh	; SI = string location
os_string_uppercase				equ 0021h	; AX = zero-terminated string
os_string_lowercase				equ 0024h	; AX = zero-terminated string
os_string_compare				equ 0027h	; SI, DI = strings, carry set if same

; Math control

os_get_random					equ 002Dh	; IN: AX, BX = low, high; OUT: CX = num

; Misc OS functions

os_pause						equ 0030h	; AX = 10ths of second to wait
os_fatal_error					equ 0033h	; AX = error string location