section .data
    ; Error messages
    err_no_id db "nok: no identifier provided", 10
    err_no_id_len equ $ - err_no_id
    
    err_exists db "nok: user already exists", 10
    err_exists_len equ $ - err_exists
    
    success_msg db "ok: user created!", 10
    success_msg_len equ $ - success_msg
    
    ; File paths
    wall_suffix db "/wall", 0
    friends_suffix db "/friends", 0
    
section .bss
    username resb 256
    username_len resd 1
    wall_path resb 512
    friends_path resb 512
    
section .text
    global _start

_start:
    ; Get argc from stack
    pop eax                 ; argc
    cmp eax, 2
    jne no_identifier       ; If argc != 2, no identifier provided
    
    ; Get argv[1] (username)
    pop ebx                 ; skip argv[0]
    pop ebx                 ; ebx = argv[1] (pointer to username string)
    
    ; Copy username and calculate length
    mov esi, ebx
    mov edi, username
    xor ecx, ecx            ; length counter
    
copy_username:
    lodsb                   ; load byte from [esi] to al
    test al, al             ; check if null terminator
    jz username_copied
    stosb                   ; store byte from al to [edi]
    inc ecx
    cmp ecx, 255
    jl copy_username
    
username_copied:
    mov byte [edi], 0       ; null terminate
    mov [username_len], ecx
    
    ; Check if user directory already exists
    ; Try to open the directory (using sys_open with O_DIRECTORY)
    mov eax, 5              ; sys_open
    mov ebx, username
    mov ecx, 0200000o       ; O_DIRECTORY flag
    mov edx, 0
    int 0x80
    
    cmp eax, 0
    jge user_exists         ; If successful, directory exists
    
    ; Create user directory
    mov eax, 39             ; sys_mkdir
    mov ebx, username
    mov ecx, 0755o          ; permissions: rwxr-xr-x
    int 0x80
    
    cmp eax, 0
    jl exit_error           ; If mkdir failed, exit with error
    
    ; Build wall file path: username/wall
    mov esi, username
    mov edi, wall_path
    
copy_wall_path:
    lodsb
    test al, al
    jz wall_path_base_done
    stosb
    jmp copy_wall_path
    
wall_path_base_done:
    ; Append "/wall"
    mov esi, wall_suffix
copy_wall_suffix:
    lodsb
    stosb
    test al, al
    jnz copy_wall_suffix
    
    ; Create wall file
    mov eax, 8              ; sys_creat
    mov ebx, wall_path
    mov ecx, 0644o          ; permissions: rw-r--r--
    int 0x80
    
    cmp eax, 0
    jl exit_error
    
    ; Close wall file
    mov ebx, eax            ; file descriptor
    mov eax, 6              ; sys_close
    int 0x80
    
    ; Build friends file path: username/friends
    mov esi, username
    mov edi, friends_path
    
copy_friends_path:
    lodsb
    test al, al
    jz friends_path_base_done
    stosb
    jmp copy_friends_path
    
friends_path_base_done:
    ; Append "/friends"
    mov esi, friends_suffix
copy_friends_suffix:
    lodsb
    stosb
    test al, al
    jnz copy_friends_suffix
    
    ; Create friends file
    mov eax, 8              ; sys_creat
    mov ebx, friends_path
    mov ecx, 0644o          ; permissions: rw-r--r--
    int 0x80
    
    cmp eax, 0
    jl exit_error
    
    ; Close friends file
    mov ebx, eax            ; file descriptor
    mov eax, 6              ; sys_close
    int 0x80
    
    ; Print success message
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov ecx, success_msg
    mov edx, success_msg_len
    int 0x80
    
    jmp exit_success

no_identifier:
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov ecx, err_no_id
    mov edx, err_no_id_len
    int 0x80
    jmp exit_error

user_exists:
    ; Close the file descriptor from the check
    mov ebx, eax
    mov eax, 6              ; sys_close
    int 0x80
    
    mov eax, 4              ; sys_write
    mov ebx, 1              ; stdout
    mov ecx, err_exists
    mov edx, err_exists_len
    int 0x80
    jmp exit_error

exit_error:
    mov eax, 1              ; sys_exit
    mov ebx, 1              ; exit code 1
    int 0x80

exit_success:
    mov eax, 1              ; sys_exit
    xor ebx, ebx            ; exit code 0
    int 0x80