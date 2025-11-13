section .data
    ; Error messages
    err_user_not_exist db "nok: user '"
    err_user_not_exist_len equ $ - err_user_not_exist
    err_not_exist_suffix db "' does not exist", 10
    err_not_exist_suffix_len equ $ - err_not_exist_suffix
    
    success_msg db "ok", 10
    success_msg_len equ $ - success_msg
    
    friends_suffix db "/friends", 0
    newline db 10
    
section .bss
    user_id resb 256
    friend_id resb 256
    friends_file_path resb 512
    read_buffer resb 4096
    
section .text
    global _start

_start:
    ; Get argc
    pop eax
    cmp eax, 3
    jne exit_error      ; Need exactly 2 arguments (plus program name)
    
    ; Get argv[0] (program name - skip)
    pop ebx
    
    ; Get argv[1] (user_id)
    pop esi             ; esi = pointer to user_id string
    mov edi, user_id
    call strcpy
    
    ; Get argv[2] (friend_id)
    pop esi             ; esi = pointer to friend_id string
    mov edi, friend_id
    call strcpy
    
    ; Check if user directory exists
    mov eax, 5          ; sys_open
    mov ebx, user_id
    mov ecx, 0200000o   ; O_DIRECTORY
    mov edx, 0
    int 0x80
    cmp eax, 0
    jl user_not_exists
    
    ; Close the directory fd
    mov ebx, eax
    mov eax, 6
    int 0x80
    
    ; Check if friend directory exists
    mov eax, 5          ; sys_open
    mov ebx, friend_id
    mov ecx, 0200000o   ; O_DIRECTORY
    mov edx, 0
    int 0x80
    cmp eax, 0
    jl friend_not_exists
    
    ; Close the directory fd
    mov ebx, eax
    mov eax, 6
    int 0x80
    
    ; Build friends file path: user_id/friends
    mov esi, user_id
    mov edi, friends_file_path
    call strcpy
    mov esi, friends_suffix
    call strcpy
    
    ; Open friends file for reading
    mov eax, 5          ; sys_open
    mov ebx, friends_file_path
    mov ecx, 0          ; O_RDONLY
    mov edx, 0
    int 0x80
    
    cmp eax, 0
    jl friend_not_in_list  ; File doesn't exist or can't open, so friend not in list
    
    mov esi, eax        ; save file descriptor
    
    ; Read friends file
    mov eax, 3          ; sys_read
    mov ebx, esi
    mov ecx, read_buffer
    mov edx, 4096
    int 0x80
    
    push eax            ; save bytes read
    
    ; Close file
    mov eax, 6
    mov ebx, esi
    int 0x80
    
    pop edx             ; edx = bytes read
    
    ; Check if friend_id is in the buffer
    cmp edx, 0
    jle friend_not_in_list  ; Empty file or error
    
    ; Search for friend_id in buffer (line by line)
    mov esi, read_buffer    ; esi = current position in buffer
    mov edi, friend_id      ; edi = friend_id to search for
    
search_loop:
    cmp edx, 0
    jle friend_not_in_list
    
    ; Compare current line with friend_id
    push esi            ; save buffer position
    push edi            ; save friend_id pointer
    push edx            ; save remaining bytes
    
compare_line:
    mov al, [esi]       ; get character from buffer
    mov bl, [edi]       ; get character from friend_id
    
    ; Check if we've reached the end of friend_id
    test bl, bl
    jz check_line_end   ; friend_id ended, check if line ends too
    
    ; Compare characters
    cmp al, bl
    jne skip_to_next_line  ; different, skip this line
    
    inc esi
    inc edi
    jmp compare_line
    
check_line_end:
    ; friend_id matched, now check if this is end of line
    mov al, [esi]
    cmp al, 10          ; newline?
    je friend_already_exists
    test al, al         ; null terminator (end of buffer)?
    jz friend_already_exists
    ; Otherwise, continue - this was a prefix match
    
skip_to_next_line:
    ; Restore registers
    pop edx
    pop edi
    pop esi
    
    ; Skip to next line
find_newline:
    cmp edx, 0
    jle friend_not_in_list
    lodsb               ; load byte and increment esi
    dec edx
    cmp al, 10          ; newline?
    jne find_newline
    
    ; Now at start of next line, try again
    jmp search_loop
    
friend_already_exists:
    ; Clean up stack
    pop edx
    pop edi
    pop esi
    
    ; Friend already in list, just print ok and exit
    jmp print_ok

friend_not_in_list:
    ; Append friend to friends file
    mov eax, 5          ; sys_open
    mov ebx, friends_file_path
    mov ecx, 02001o     ; O_WRONLY | O_APPEND
    mov edx, 0644o      ; permissions (in case file needs to be created)
    int 0x80
    
    cmp eax, 0
    jl exit_error
    
    mov esi, eax        ; save file descriptor
    
    ; Calculate friend_id length
    mov edi, friend_id
    xor ecx, ecx
calc_len:
    mov al, [edi]
    test al, al
    jz len_done
    inc edi
    inc ecx
    jmp calc_len
    
len_done:
    ; Write friend_id
    mov eax, 4          ; sys_write
    mov ebx, esi        ; file descriptor
    mov ecx, friend_id
    mov edx, ecx        ; Save length
    push edx
    mov edi, friend_id
    xor edx, edx
count_again:
    mov al, [edi]
    test al, al
    jz write_it
    inc edi
    inc edx
    jmp count_again
    
write_it:
    mov eax, 4
    mov ebx, esi
    mov ecx, friend_id
    int 0x80
    
    ; Write newline
    mov eax, 4
    mov ebx, esi
    mov ecx, newline
    mov edx, 1
    int 0x80
    
    ; Close file
    mov eax, 6
    mov ebx, esi
    int 0x80

    ; ========================================
    ; Now add the reverse friendship!
    ; Add user_id to friend_id's friends list
    ; ========================================
    
    ; Build friend's friends file path: friend_id/friends
    mov esi, friend_id
    mov edi, friends_file_path
    call strcpy
    mov esi, friends_suffix
    call strcpy
    
    ; Check if user_id is already in friend's friends list
    ; Open friend's friends file for reading
    mov eax, 5          ; sys_open
    mov ebx, friends_file_path
    mov ecx, 0          ; O_RDONLY
    mov edx, 0
    int 0x80
    
    cmp eax, 0
    jl add_reverse_friendship  ; File doesn't exist, definitely not there
    
    mov esi, eax        ; save file descriptor
    
    ; Read friends file
    mov eax, 3          ; sys_read
    mov ebx, esi
    mov ecx, read_buffer
    mov edx, 4096
    int 0x80
    
    push eax            ; save bytes read
    
    ; Close file
    mov eax, 6
    mov ebx, esi
    int 0x80
    
    pop edx             ; edx = bytes read
    
    ; Check if user_id is already in the buffer
    cmp edx, 0
    jle add_reverse_friendship  ; Empty file
    
    ; Search for user_id in buffer (line by line)
    mov esi, read_buffer
    
search_reverse:
    cmp edx, 0
    jle add_reverse_friendship
    
    ; Compare current line with user_id
    push esi
    push edx
    mov edi, user_id
    
compare_reverse:
    mov al, [esi]
    mov bl, [edi]
    
    test bl, bl
    jz check_reverse_eol
    
    cmp al, bl
    jne next_reverse_line
    
    inc esi
    inc edi
    jmp compare_reverse
    
check_reverse_eol:
    mov al, [esi]
    cmp al, 10
    je reverse_already_exists
    test al, al
    jz reverse_already_exists
    
next_reverse_line:
    pop edx
    pop esi
    
skip_reverse_line:
    cmp edx, 0
    jle add_reverse_friendship
    lodsb
    dec edx
    cmp al, 10
    jne skip_reverse_line
    jmp search_reverse
    
reverse_already_exists:
    pop edx
    pop esi
    jmp print_ok  ; Already bidirectional, we're done!

add_reverse_friendship:
    ; Append user_id to friend's friends file
    mov eax, 5          ; sys_open
    mov ebx, friends_file_path
    mov ecx, 02001o     ; O_WRONLY | O_APPEND
    mov edx, 0644o
    int 0x80
    
    cmp eax, 0
    jl exit_error
    
    mov esi, eax        ; save file descriptor
    
    ; Calculate user_id length
    mov edi, user_id
    xor edx, edx
calc_user_len:
    mov al, [edi]
    test al, al
    jz write_user
    inc edi
    inc edx
    jmp calc_user_len
    
write_user:
    ; Write user_id
    mov eax, 4
    mov ebx, esi
    mov ecx, user_id
    int 0x80
    
    ; Write newline
    mov eax, 4
    mov ebx, esi
    mov ecx, newline
    mov edx, 1
    int 0x80
    
    ; Close file
    mov eax, 6
    mov ebx, esi
    int 0x80

print_ok:
    mov eax, 4
    mov ebx, 1
    mov ecx, success_msg
    mov edx, success_msg_len
    int 0x80
    jmp exit_success

user_not_exists:
    ; Print "nok: user '"
    mov eax, 4
    mov ebx, 1
    mov ecx, err_user_not_exist
    mov edx, err_user_not_exist_len
    int 0x80
    
    ; Print user_id
    mov edi, user_id
    xor edx, edx
strlen_user:
    mov al, [edi]
    test al, al
    jz print_user
    inc edi
    inc edx
    jmp strlen_user
print_user:
    mov eax, 4
    mov ebx, 1
    mov ecx, user_id
    int 0x80
    
    ; Print "' does not exist\n"
    mov eax, 4
    mov ebx, 1
    mov ecx, err_not_exist_suffix
    mov edx, err_not_exist_suffix_len
    int 0x80
    jmp exit_error

friend_not_exists:
    ; Print "nok: user '"
    mov eax, 4
    mov ebx, 1
    mov ecx, err_user_not_exist
    mov edx, err_user_not_exist_len
    int 0x80
    
    ; Print friend_id
    mov edi, friend_id
    xor edx, edx
strlen_friend:
    mov al, [edi]
    test al, al
    jz print_friend
    inc edi
    inc edx
    jmp strlen_friend
print_friend:
    mov eax, 4
    mov ebx, 1
    mov ecx, friend_id
    int 0x80
    
    ; Print "' does not exist\n"
    mov eax, 4
    mov ebx, 1
    mov ecx, err_not_exist_suffix
    mov edx, err_not_exist_suffix_len
    int 0x80
    jmp exit_error

exit_error:
    mov eax, 1
    mov ebx, 1
    int 0x80

exit_success:
    mov eax, 1
    xor ebx, ebx
    int 0x80

; Helper function to copy string
; Input: esi = source, edi = dest
; Output: edi points after null terminator
strcpy:
strcpy_loop:
    lodsb
    stosb
    test al, al
    jnz strcpy_loop
    dec edi             ; back up over null terminator
    ret