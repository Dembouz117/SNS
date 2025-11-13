section .data
    ; Messages
    err_not_exist db "nok: user "
    err_not_exist_len equ $ - err_not_exist
    err_suffix db " does not exist", 10
    err_suffix_len equ $ - err_suffix
    
    start_msg db "start_of_file", 10
    start_msg_len equ $ - start_msg
    
    end_msg db "end_of_file", 10
    end_msg_len equ $ - end_msg
    
    wall_suffix db "/wall", 0
    
section .bss
    user_id resb 256
    wall_path resb 512
    read_buffer resb 4096
    
section .text
    global _start

; Helper function to calculate string length
strlen:
    push esi
    xor ecx, ecx
strlen_loop:
    lodsb
    test al, al
    jz strlen_done
    inc ecx
    jmp strlen_loop
strlen_done:
    pop esi
    ret

; Helper function to copy string
strcpy:
    push esi
strcpy_loop:
    lodsb
    stosb
    test al, al
    jnz strcpy_loop
    dec edi
    pop esi
    ret

; Helper function to check if directory exists
check_dir_exists:
    mov eax, 5
    mov ecx, 0200000o
    mov edx, 0
    int 0x80
    cmp eax, 0
    jl dir_not_exists
    mov ebx, eax
    push eax
    mov eax, 6
    int 0x80
    pop eax
    xor eax, eax
    ret
dir_not_exists:
    mov eax, -1
    ret

; Print string to stdout
print_string:
    push eax
    push ebx
    mov eax, 4
    mov ebx, 1
    int 0x80
    pop ebx
    pop eax
    ret

_start:
    ; Get argc
    pop eax
    cmp eax, 2
    jne exit_error      ; Need exactly 1 argument
    
    ; Get argv[0] (program name - skip)
    pop ebx
    
    ; Get argv[1] (user_id)
    pop esi
    mov edi, user_id
    call strcpy
    
    ; Check if user exists
    mov ebx, user_id
    call check_dir_exists
    cmp eax, 0
    jne user_not_exists
    
    ; Build wall path: user_id/wall
    mov esi, user_id
    mov edi, wall_path
    call strcpy
    mov esi, wall_suffix
    call strcpy
    
    ; Print "start_of_file"
    mov ecx, start_msg
    mov edx, start_msg_len
    call print_string
    
    ; Open wall file for reading
    mov eax, 5
    mov ebx, wall_path
    mov ecx, 0          ; O_RDONLY
    mov edx, 0
    int 0x80
    
    cmp eax, 0
    jl file_empty       ; Error opening file (or empty)
    
    mov esi, eax        ; save file descriptor

read_loop:
    ; Read from wall file
    mov eax, 3
    mov ebx, esi
    mov ecx, read_buffer
    mov edx, 4096
    int 0x80
    
    cmp eax, 0
    jle read_done       ; No more data or error
    
    ; Write buffer to stdout
    push eax            ; save bytes read
    mov edx, eax        ; bytes to write
    mov eax, 4
    mov ebx, 1
    mov ecx, read_buffer
    int 0x80
    pop eax
    
    cmp eax, 4096       ; Check if we filled the buffer
    je read_loop        ; If yes, there might be more data
    
read_done:
    ; Close file
    mov eax, 6
    mov ebx, esi
    int 0x80

file_empty:
    ; Print "end_of_file"
    mov ecx, end_msg
    mov edx, end_msg_len
    call print_string
    jmp exit_success

user_not_exists:
    mov ecx, err_not_exist
    mov edx, err_not_exist_len
    call print_string
    
    mov esi, user_id
    call strlen
    mov ecx, user_id
    mov edx, ecx
    call print_string
    
    mov ecx, err_suffix
    mov edx, err_suffix_len
    call print_string
    jmp exit_error

exit_error:
    mov eax, 1
    mov ebx, 1
    int 0x80

exit_success:
    mov eax, 1
    xor ebx, ebx
    int 0x80