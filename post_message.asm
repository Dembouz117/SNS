section .data
    ; Error messages
    err_sender db "nok: user "
    err_sender_len equ $ - err_sender
    err_receiver db "nok: user "
    err_receiver_len equ $ - err_receiver
    err_not_exist db " does not exist", 10
    err_not_exist_len equ $ - err_not_exist
    err_not_friend db "nok: user "
    err_not_friend_len equ $ - err_not_friend
    err_not_friend_mid db " is not a friend of "
    err_not_friend_mid_len equ $ - err_not_friend_mid
    
    success_msg db "ok", 10
    success_msg_len equ $ - success_msg
    
    wall_suffix db "/wall", 0
    friends_suffix db "/friends", 0
    colon_space db ": "
    newline db 10
    
section .bss
    sender_id resb 256
    receiver_id resb 256
    message resb 2048
    wall_path resb 512
    friends_path resb 512
    read_buffer resb 4096
    message_arg_count resd 1
    
section .text
    global _start

_start:
    ; Get argc
    pop eax
    cmp eax, 4          ; Need at least 3 arguments (sender, receiver, message)
    jl exit_error
    
    ; Calculate and save message arg count
    sub eax, 3          ; argc - program - sender - receiver
    mov [message_arg_count], eax
    
    ; Get argv[0] (program name - skip)
    pop ebx
    
    ; Get argv[1] (sender_id)
    pop esi             ; esi = pointer to sender string
    mov edi, sender_id
    call strcpy
    
    ; Get argv[2] (receiver_id)
    pop esi             ; esi = pointer to receiver string
    mov edi, receiver_id
    call strcpy
    
    ; Get argv[3...n] (message parts)
    mov edi, message    ; edi = destination for message
    mov ecx, [message_arg_count]  ; ecx = number of message args
    
copy_message_args:
    cmp ecx, 0
    jle message_done
    
    ; Add space if not first arg
    cmp edi, message
    je first_arg
    mov byte [edi], 32  ; space
    inc edi
    
first_arg:
    pop esi             ; Get next message argument
    
copy_arg:
    lodsb
    test al, al
    jz arg_done
    stosb
    jmp copy_arg
    
arg_done:
    dec ecx
    jmp copy_message_args
    
message_done:
    mov byte [edi], 0   ; null terminate message
    
    ; Check if sender exists
    mov eax, 5          ; sys_open
    mov ebx, sender_id
    mov ecx, 0200000o   ; O_DIRECTORY
    mov edx, 0
    int 0x80
    cmp eax, 0
    jl sender_not_exists
    
    ; Close directory fd
    mov ebx, eax
    mov eax, 6
    int 0x80
    
    ; Check if receiver exists
    mov eax, 5          ; sys_open
    mov ebx, receiver_id
    mov ecx, 0200000o   ; O_DIRECTORY
    mov edx, 0
    int 0x80
    cmp eax, 0
    jl receiver_not_exists
    
    ; Close directory fd
    mov ebx, eax
    mov eax, 6
    int 0x80
    
    ; Build receiver's friends file path
    mov esi, receiver_id
    mov edi, friends_path
    call strcpy
    mov esi, friends_suffix
    call strcpy
    
    ; Open and read receiver's friends file
    mov eax, 5          ; sys_open
    mov ebx, friends_path
    mov ecx, 0          ; O_RDONLY
    mov edx, 0
    int 0x80
    cmp eax, 0
    jl not_friends      ; Can't open = not friends
    
    mov esi, eax        ; Save fd
    
    ; Read friends file
    mov eax, 3          ; sys_read
    mov ebx, esi
    mov ecx, read_buffer
    mov edx, 4096
    int 0x80
    
    push eax            ; Save bytes read
    
    ; Close file
    mov eax, 6
    mov ebx, esi
    int 0x80
    
    pop edx             ; edx = bytes read
    
    ; Search for sender in friends list
    cmp edx, 0
    jle not_friends
    
    mov esi, read_buffer
    
search_friends:
    cmp edx, 0
    jle not_friends
    
    ; Compare line with sender_id
    push esi
    push edx
    mov edi, sender_id
    
compare_friend:
    mov al, [esi]
    mov bl, [edi]
    
    test bl, bl         ; End of sender_id?
    jz check_eol
    
    cmp al, bl
    jne next_friend
    
    inc esi
    inc edi
    jmp compare_friend
    
check_eol:
    mov al, [esi]
    cmp al, 10          ; newline?
    je is_friend
    test al, al         ; end of buffer?
    jz is_friend
    
next_friend:
    pop edx
    pop esi
    
skip_line:
    cmp edx, 0
    jle not_friends
    lodsb
    dec edx
    cmp al, 10
    jne skip_line
    jmp search_friends
    
is_friend:
    pop edx
    pop esi
    
    ; Build wall file path
    mov esi, receiver_id
    mov edi, wall_path
    call strcpy
    mov esi, wall_suffix
    call strcpy
    
    ; Open wall file for appending
    mov eax, 5          ; sys_open
    mov ebx, wall_path
    mov ecx, 02001o     ; O_WRONLY | O_APPEND
    mov edx, 0
    int 0x80
    cmp eax, 0
    jl exit_error
    
    mov esi, eax        ; Save fd
    
    ; Write sender_id
    mov edi, sender_id
    xor edx, edx
calc_sender_len:
    mov al, [edi]
    test al, al
    jz write_sender
    inc edi
    inc edx
    jmp calc_sender_len
    
write_sender:
    mov eax, 4          ; sys_write
    mov ebx, esi
    mov ecx, sender_id
    int 0x80
    
    ; Write ": "
    mov eax, 4
    mov ebx, esi
    mov ecx, colon_space
    mov edx, 2
    int 0x80
    
    ; Write message
    mov edi, message
    xor edx, edx
calc_msg_len:
    mov al, [edi]
    test al, al
    jz write_msg
    inc edi
    inc edx
    jmp calc_msg_len
    
write_msg:
    mov eax, 4
    mov ebx, esi
    mov ecx, message
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
    
    ; Print success
    mov eax, 4
    mov ebx, 1
    mov ecx, success_msg
    mov edx, success_msg_len
    int 0x80
    jmp exit_success

sender_not_exists:
    ; Print error
    mov eax, 4
    mov ebx, 1
    mov ecx, err_sender
    mov edx, err_sender_len
    int 0x80
    
    mov edi, sender_id
    xor edx, edx
len_sender:
    mov al, [edi]
    test al, al
    jz print_sender
    inc edi
    inc edx
    jmp len_sender
print_sender:
    mov eax, 4
    mov ebx, 1
    mov ecx, sender_id
    int 0x80
    
    mov eax, 4
    mov ebx, 1
    mov ecx, err_not_exist
    mov edx, err_not_exist_len
    int 0x80
    jmp exit_error

receiver_not_exists:
    mov eax, 4
    mov ebx, 1
    mov ecx, err_receiver
    mov edx, err_receiver_len
    int 0x80
    
    mov edi, receiver_id
    xor edx, edx
len_receiver:
    mov al, [edi]
    test al, al
    jz print_receiver
    inc edi
    inc edx
    jmp len_receiver
print_receiver:
    mov eax, 4
    mov ebx, 1
    mov ecx, receiver_id
    int 0x80
    
    mov eax, 4
    mov ebx, 1
    mov ecx, err_not_exist
    mov edx, err_not_exist_len
    int 0x80
    jmp exit_error

not_friends:
    mov eax, 4
    mov ebx, 1
    mov ecx, err_not_friend
    mov edx, err_not_friend_len
    int 0x80
    
    mov edi, sender_id
    xor edx, edx
len_sender2:
    mov al, [edi]
    test al, al
    jz print_sender2
    inc edi
    inc edx
    jmp len_sender2
print_sender2:
    mov eax, 4
    mov ebx, 1
    mov ecx, sender_id
    int 0x80
    
    mov eax, 4
    mov ebx, 1
    mov ecx, err_not_friend_mid
    mov edx, err_not_friend_mid_len
    int 0x80
    
    mov edi, receiver_id
    xor edx, edx
len_receiver2:
    mov al, [edi]
    test al, al
    jz print_receiver2
    inc edi
    inc edx
    jmp len_receiver2
print_receiver2:
    mov eax, 4
    mov ebx, 1
    mov ecx, receiver_id
    int 0x80
    
    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
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

; Helper: copy string from esi to edi
strcpy:
strcpy_loop:
    lodsb
    stosb
    test al, al
    jnz strcpy_loop
    dec edi
    ret