; ---------------------------------------------------------------
; os_get_file_list -- Generate comma-separated string of files on floppy
; IN/OUT: AX = location to store zero zero-terminated filename string

os_get_file_list:
	pusha
	
	mov WORD [.file_list_tmp], ax
	
	mov eax, 0				; Needed for some older BIOSes
	
	call disk_reset_floppy		; In case disk was changed
	
	mov ax, 19					; Root dir starts at logical sector 19
	call disk_convert_l2hts
	
	mov si, disk_buffer			; ES:BX should point to our buffer
	mov bx, si
	
	mov ah, 2					; Params for int 13h: read floppy sectors
	mov al, 14					; And read 14 of them
	
	pusha						; Prepare to enter loop
	

.read_root_dir:
	popa
	pusha
	
	stc
	int 13h						; Read sectors
	call disk_reset_floppy		; Check we've read them OK
	jnc .show_dir_init			; No errors, continue
	
	call disk_reset_floppy		; Error = reset controller and try again
	jnc .read_root_dir
	jmp .done					; Double error, exit 'dir' routine
	
.show_dir_init:
	popa
	
	mov ax, 0
	mov si, disk_buffer			; Data render from start of filenames
	
	mov WORD di, [.file_list_tmp]	; Name destination buffer
	

.start_entry:
	mov al, [si+11]				; File attributes for entry
	cmp al, 0Fh					; Windows marker, skip it
	je .skip
	
	test al, 18h				; Is this a directory entry or volume label?
	jnz .skip					; Yes, ignore it
	
	mov al, [si]
	cmp al, 229					; If we read 229 = deleted filename
	je .skip
	
	cmp al, 0					; 1st byte = entry never used
	je .done
	
	
	mov cx, 1					; Set char counter
	mov dx, si					; Beginning of possible entry
	
.testdirentry:
	inc si
	mov al, [si]				; Test for most usable characters
	cmp al, ' '					; Windows sometimes puts 0 (UTF-8) or 0FFh
	jl .nxtdirentry
	cmp al, '~'
	ja .nxtdirentry		
	
	inc cx
	cmp cx, 11					; Done 11 char filename?
	je .gotfilename
	jmp .testdirentry
	
.gotfilename:					; Got a filename that passes testing
	mov si, dx					; DX = where getting string
	
	mov cx, 0
.loopy:
	mov BYTE al, [si]
	cmp al, ' '
	je .ignore_space
	mov byte [di], al
	inc si
	inc di
	inc cx
	cmp cx, 8
	je .add_dot
	cmp cx, 11
	je .done_copy
	jmp .loopy
	
.ignore_space:
	inc si
	inc cx
	cmp cx, 8
	je .add_dot
	jmp .loopy
	
.add_dot:
	mov byte [di], '.'
	inc di
	jmp .loopy
	
.done_copy:
	mov BYTE [di], ','			; Use comma to separate filenames
	inc di
	
.nxtdirentry:
	mov si, dx					; Start of entry, pretend to skip to next
	
.skip:
	add si, 32					; Shift to next 32 byte (next filename)
	jmp .start_entry
	
	
.done:
	dec di
	mov BYTE [di], 0			; Zero-terminated string (gets rid of final comma)
	
	popa
	ret
	
	.file_list_tmp		dw 0
	
; ---------------------------------------------------------------
; os_load_file -- Load file into RAM
; IN: AX = location of filename, CX = location in RAM to load file
; OUT: BX = file size (in byte), carry set if file not found

os_load_file:
	call os_string_uppercase
	call int_filename_convert
	
	mov [.filename_loc], ax		; Store filename location
	mov [.load_position], cx	; And where to load the file!
	
	mov eax, 0					; Needed for some older BIOSes
	
	call disk_reset_floppy		; In case floppy has been changed
	jnc .floppy_ok				; Did the floppy reset OK?
	
	mov ax, .err_msg_floppy_reset	; If not, bail out
	jmp os_fatal_error
	

.floppy_ok:						; Ready to read first block of data
	mov ax, 19					; Root dir starts at logical sector 19
	call disk_convert_l2hts
	
	mov si, disk_buffer			; ES:BX should point to our buffer
	mov bx, si
	
	mov ah, 2					; Params for int 13h: read floppy sectors
	mov al, 14					; 14 root directory sectors
	
	pusha						; Prepare to enter loop
	
	
.read_root_dir:
	popa
	pusha
	
	stc							; A few BIOSes clear, but doesn't set properly
	int 13h						; Read sectors
	jnc .search_root_dir		; No errors = continue
	
	call disk_reset_floppy		; Problem = reset controller and try again
	jnc .read_root_dir
	
	popa
	jmp .root_problem			; Double error = exit
	
.search_root_dir:
	popa
	
	mov cx, WORD 224			; Search all entries in root dir
	mov bx, -32					; Begin searching at offset 0 in root dir
	
.next_root_entry:
	add bx, 32					; Bump searched entries by 1 (offset + 32 bytes)
	mov di, disk_buffer			; Point root dir at next entry
	add di, bx
	
	mov al, [di]				; First character of name
	
	cmp al, 0					; Last file name already checked?
	je .root_problem
	
	cmp al, 229					; Was this file deleted?
	je .next_root_entry			; If yes, skip it
	
	mov al, [di+11]				; Get the attribute byte
	
	cmp al, 0Fh					; Is this a special Windows entry?
	je .next_root_entry
	
	test al, 18h				; Is this a directory entry or volume label?
	jnz .next_root_entry
	
	mov byte [di+11], 0			; Add a terminator to directory name entry
	
	mov ax, di					; Convert root buffer name to upper case
	call os_string_uppercase
	
	mov si, [.filename_loc]		; DS:SI = location of filename to load
	
	call os_string_compare		; Current entry same as requested?
	jc .found_file_to_load
	
	loop .next_root_entry
	
.root_problem:
	mov bx, 0					; If file not found or major disk error,
	stc							; return with size = 0 and carry set
	ret
	
	
.found_file_to_load:			; Now fetch cluster and load FAT into RAM
	mov ax, [di+28]				; Store file size to return to calling routine
	mov WORD [.file_size], ax
	
	cmp ax, 0					; If the file size is zero, don't bother trying
	je .end						; to read more clusters
	
	mov ax, [di+26]				; Now fetch cluster and load FAT into RAM
	mov WORD [.cluster], ax
	
	mov ax, 1					; Sector 1 = first sector of first FAT
	call disk_convert_l2hts
	
	mov di, disk_buffer			; ES:BX points to our buffer
	mov bx, di
	
	mov ah, 2					; int 13h params: read sectors
	mov al, 9					; And read 9 of them
	
	pusha
	
.read_fat:
	popa						; In case registers altered by int 13h
	pusha
	
	stc
	int 13h
	jnc .read_fat_ok
	
	call disk_reset_floppy
	jnc .read_fat
	
	popa
	jmp .root_problem
	

.read_fat_ok:
	popa
	
	
.load_file_sector:
	mov ax, WORD [.cluster]		; Convert sector to logical
	add ax, 31
	
	call disk_convert_l2hts		; Make appropiriate params for int 13h
	
	mov bx, [.load_position]
	
	
	mov ah, 02					; AH = read sectors, AL = just read 1
	mov al, 01
	
	stc
	int 13h
	jnc .calculate_next_cluster	; If there's no error...
	
	call disk_reset_floppy		; Otherwise, reset floppy and retry
	jnc .load_file_sector
	
	mov ax, .err_msg_floppy_reset	; Reset failed, bail out
	jmp os_fatal_error
	
	
.calculate_next_cluster:
	mov ax, [.cluster]
	mov bx, 3
	mul bx
	mov bx, 2
	div bx						; DX = [CLUSTER] mod 2
	mov si, disk_buffer			; AX = word in FAT for the 12 bits
	add si, ax
	mov ax, WORD [ds:si]
	
	or dx, dx					; If DX = 0 [CLUSTER] = even, if DX = 1 then odd
	
	jz .even					; If [CLUSTER] = even, drop last 4 bits of word
								; with next cluster, if odd, drop first 4 bits
								
.odd:
	shr ax, 4					; Shift out first 4 bits (belong to another entry)
	jmp .calculate_cluster_cont	; Onto next sector!
	
.even:
	and ax, 0FFFh				; Mask out top (last) 4 bits
	
.calculate_cluster_cont:
	mov WORD [.cluster], ax		; Store cluster
	
	cmp ax, 0FF8h
	jae .end
	
	add WORD [.load_position], 512
	jmp .load_file_sector		; Onto next sector!
	
	
.end:
	mov bx, [.file_size]		; Get file size to pass back in BX
	clc							; Carry clear = good load
	ret
	
	
	.bootd		db 0			; Boot device number
	.cluster	dw 0			; Cluster of the file we want to load
	.pointer	dw 0			; Pointer into disk_buffer, flor loading 'file2load'
	
	.filename_loc	dw 0		; Temporary store of filename location
	.load_position	dw 0		; Where we'll load the file
	.file_size		dw 0		; Size of the file
	
	.string_buff	times 12 db 0		; For size (integer) printing
	
	.err_msg_floppy_reset	 db 'os_load_file: Floppy failed to reset', 0
	
	
; ---------------------------------------------------------------
; os_file_exists -- Check for presence of file on the floppy
; IN: AX = filename location; OUT: carry clear if found, set if not

os_file_exists:
	call os_string_uppercase
	call int_filename_convert	; Mae FAT12-style filename
	
	push ax
	call os_string_length
	cmp ax, 0
	je .failure
	pop ax
	
	push ax
	call disk_read_root_dir
	
	pop ax						; Restore filename
	
	mov di, disk_buffer
	
	call disk_get_root_entry	; Set or clear carry flag
	
	ret
	
.failure:
	pop ax
	stc
	ret
	

; ---------------------------------------------------------------
; os_get_file_size -- Get file size information for specified file
; IN: AX = filename; OUT: BX = file size in bytes (up to 64K)
; or carry set if file not found

os_get_file_size:
	pusha
	
	call os_string_uppercase
	call int_filename_convert
	
	clc
	
	push ax
	
	call disk_read_root_dir
	jc .failure
	
	pop ax
	mov di, disk_buffer
	
	call disk_get_root_entry
	jc .failure
	
	mov WORD bx, [di+28]
	
	mov WORD [.tmp], bx
	
	popa
	
	mov WORD bx, [.tmp]
	
	ret
	
.failure:
	popa
	stc
	ret
	
	
	.tmp	dw 0
	
; ===============================================================
; INTERNAL OS ROUTINES -- Not accessible to user programs

; ---------------------------------------------------------------
; int_filename_convert -- Change 'TEST.BIN' into 'TEST    BIN' as per FAT12
; IN: AX = filename string
; OUT: AX = location of converted string (carry set if invalid)

int_filename_convert:
	pusha
	
	mov si, ax
	
	call os_string_length
	cmp ax, 14					; Filename too long?
	jg .failure					; Fail if so
	
	cmp ax, 0
	je .failure					; Similarly, fail if zero-char string
	
	mov dx, ax					; Store string length for now
	
	mov di, .dest_string
	
	mov cx, 0
.copy_loop:
	lodsb
	cmp al, '.'
	je .extension_found
	stosb
	inc cx
	cmp cx, dx
	jg .failure					; No extension found = wrong
	jmp .copy_loop
	
.extension_found:
	cmp cx, 0
	je .failure					; Fail if extension dot is first char
	
	cmp cx, 8
	je .do_extension			; Skip spaces if first bit is 8 chars
	
	; Now it's time to pad out the rest of the first part of the filename
	; with spaces, if necessary
	
.add_spaces:
	mov BYTE [di], ' '
	inc di
	inc cx
	cmp cx, 8
	jl .add_spaces
	
	; Finally, copy over the extension
.do_extension:
	lodsb						; 3 characters
	cmp al, 0
	je .failure
	stosb
	lodsb
	cmp al, 0
	je .failure
	stosb
	lodsb
	cmp al, 0
	je .failure
	stosb
	
	mov BYTE [di], 0			; Zero-terminate filename
	
	popa
	mov ax, .dest_string
	clc							; Clear carry for success
	ret
	
.failure:
	popa
	stc							; Set carry for failure
	ret
	
	
	.dest_string	times 13 db 0
	
	
; ---------------------------------------------------------------
; disk_get_root_entry -- Search RAM copy of root dir for file entry
; IN: AX = filename; OUT: DI = location in disk_buffer of root dir entry,
; or carry set if file not found

disk_get_root_entry:
	pusha
	
	mov WORD [.filename], ax
	
	mov cx, 224					; Search all (224) entries
	mov ax, 0					; Searchng at offset 0
	
.to_next_root_entry:
	xchg cx, dx					; We use CX in the inner loop...
	
	mov WORD si, [.filename]	; Start searching for filename
	mov cx, 11
	rep cmpsb
	je .found_file				; Pointer DI will be at offset 11, if file found
	
	add ax, 32					; Bump searched entries by 1 (32 bytes/entry)
	
	mov di, disk_buffer			; Point to next root dir entry
	add di, ax
	
	xchg dx, cx					; Get the original CX back
	loop .to_next_root_entry
	
	popa
	
	stc							; Set carry if entry not found
	ret
	
	
.found_file:
	sub di, 11					; Move back to start of this root dir entry
	
	mov WORD [.tmp], di			; Restore all register except for DI
	
	popa
	
	mov WORD di, [.tmp]
	
	clc
	ret
	
	
	.filename	dw 0
	.tmp		dw 0
	

; ---------------------------------------------------------------
; disk_read_root_dir -- Get the root directory contents
; IN: Nothing; OUT: root directory contents in disk_buffer, carry set if error

disk_read_root_dir:
	pusha
	
	mov ax, 19					; Root dir starts at logical sector 19
	call disk_convert_l2hts
	
	mov si, disk_buffer			; Set SE:BX to point to OS buffer
	mov bx, ds
	mov es, bx
	mov bx, si
	
	mov ah, 2					; Params for int 13h: read floppy sectors
	mov al, 14					; And read 14 of them (from 19 onwards)
	
	pusha						; Prepare to enter loop
	
	
.read_root_dir_loop:
	popa
	pusha
	
	stc							; A few BIOSes do not set properly on error
	int 13h						; Read sectors
	
	jnc .root_dir_finished
	call disk_reset_floppy		; Reset controller and try again
	jnc .read_root_dir_loop		; Floppy reset OK?
	
	popa
	jmp .read_failure			; Fatal double error
	
.root_dir_finished:
	popa						; Restore register from main loop
	
	popa						; And restore from start of this system call
	clc							; Clear carry (for success)
	ret
	
.read_failure:
	popa
	stc							; Set carry flag (for failure)
	ret
	
	
; ---------------------------------------------------------------
; Reset floppy disk

disk_reset_floppy:
	push ax
	push dx
	mov ax, 0
; ***************************************************************
	mov dl, [bootdev]
; ***************************************************************
	stc
	int 13h
	pop dx
	pop ax
	ret
	
	
; ---------------------------------------------------------------
; disk_convert_l2hts -- Calculate head, track and sector for int 13h
; IN: logical sector in AX; OUT: correct registers for int 13h

disk_convert_l2hts:
	push bx
	push ax
	
	mov bx, ax					; Save logical sector
	
	mov dx, 0					; First the sector
	div WORD [SecsPerTrack]		; Sectors per track
	add dl, 01h					; Physical sectors start at 1
	mov cl, dl					; Sectors belong in CL for int 13h
	mov ax, bx
	
	mov dx, 0					; Now calculate the head
	div WORD [SecsPerTrack]		; Sectors per track
	mov dx, 0
	div WORD [Sides]			; Floppy sides
	mov dh, dl					; Head/side
	mov ch, al					; Track
	
	pop ax
	pop bx
	
; ***************************************************************
	mov dl, [bootdev]			; Set correct device
; ***************************************************************
	
	ret
	
	
	Sides				dw 2
	SecsPerTrack		dw 18
; ***************************************************************
	bootdev				db 0
; ***************************************************************


; ===============================================================