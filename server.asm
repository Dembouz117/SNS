section .data
    prompt db "> ", 0
    prompt_len equ $ - prompt
    
    error_msg db "nok: bad request", 10
    error_msg_len equ $ - error_msg
    
    exec_error db "nok: failed to execute program", 10
    exec_error_len equ $ - exec_error
    
    ; Program paths
    create_prog db "./create_user", 0
    add_prog db "./add_friend", 0
    post_prog db "./post_message", 0
    display_prog db "./display_wall", 0
    
    ; Command strings to match
    cmd_create db "create"
    cmd_create_len equ $ - cmd_create
    cmd_add db "add"
    cmd_add_len equ $ - cmd_add
    cmd_post db "post"
    cmd_post_len equ $ - cmd_post
    cmd_display db "display"
    cmd_display_len equ $ - cmd_display
    cmd_exit db "exit"
    cmd_exit_len equ $ - cmd_exit
    
    newline db 10
    
section .bss
    input_buffer resb 1024
    command resb 64
    args resb 10 * 256      ; Space for up to 10 arguments of 256 bytes each
    argv resb 11 * 4        ; Array of pointers (program name + 10 args + NULL)
    arg_count resd 1
    bytes_read resd 1
    
section .text
    global _start

_start:
    ; Main command loop
main_loop:
    ; Clear input buffer
    mov edi, input_buffer
    mov ecx, 256        ; 1024 bytes / 4 = 256 dwords
    xor eax, eax
clear_input:
    stosd
    loop clear_input
    
    ; Clear argv array (safety measure)
    mov edi, argv
    mov ecx, 11         ; 11 pointers (program + 10 args)
    xor eax, eax
clear_argv:
    stosd               ; Store EAX (0) and increment EDI
    loop clear_argv
    
    ; Clear args buffer too!
    mov edi, args
    mov ecx, 640        ; 10 args * 256 bytes / 4 = 640 dwords
    xor eax, eax
clear_args:
    stosd
    loop clear_args
    
    ; Print prompt
    mov eax, 4
    mov ebx, 1
    mov ecx, prompt
    mov edx, prompt_len
    int 0x80
    
    ; Read command from stdin
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, input_buffer
    mov edx, 1024
    int 0x80
    
    ; Check if read failed or EOF
    cmp eax, 0
    jle exit_program    ; EOF or error, exit
    
    mov [bytes_read], eax
    
    ; Remove trailing newline if present
    mov edi, input_buffer
    mov ecx, [bytes_read]
    add edi, ecx
    dec edi
    cmp byte [edi], 10
    jne no_newline
    mov byte [edi], 0
    dec dword [bytes_read]
    jmp parse_done
    
no_newline:
    ; Null terminate
    mov byte [edi + 1], 0
    
parse_done:
    ; Check for empty input
    cmp dword [bytes_read], 0
    jle main_loop
    
    ; Parse the command (first word)
    mov esi, input_buffer
    mov edi, command
    xor ecx, ecx
    
parse_command:
    lodsb
    cmp al, 0
    je command_parsed
    cmp al, 32          ; space
    je command_parsed
    cmp al, 9           ; tab
    je command_parsed
    stosb
    inc ecx
    cmp ecx, 63
    jl parse_command
    
command_parsed:
    mov byte [edi], 0   ; null terminate command
    
    ; Skip whitespace to get to arguments
skip_ws:
    cmp byte [esi], 32
    je skip_space
    cmp byte [esi], 9
    je skip_space
    jmp args_start
skip_space:
    inc esi
    jmp skip_ws
    
args_start:
    ; Parse arguments
    mov dword [arg_count], 0
    mov edi, args
    
parse_args_loop:
    ; Check if end of input
    mov al, [esi]
    test al, al
    jz args_done
    
    ; Store pointer to this argument in argv array
    mov ebx, [arg_count]
    inc ebx
    mov [argv + ebx * 4], edi  ; argv[1], argv[2], etc.
    inc dword [arg_count]
    
    ; Copy this argument
copy_arg:
    lodsb
    cmp al, 0
    je arg_done
    cmp al, 32
    je arg_done
    cmp al, 9
    je arg_done
    cmp al, 10
    je arg_done
    stosb
    jmp copy_arg
    
arg_done:
    mov byte [edi], 0
    inc edi
    
    ; Skip whitespace to next argument
skip_ws2:
    cmp byte [esi], 32
    je skip_space2
    cmp byte [esi], 9
    je skip_space2
    jmp check_more_args
skip_space2:
    inc esi
    jmp skip_ws2
    
check_more_args:
    mov al, [esi]
    test al, al
    jnz parse_args_loop
    
args_done:
    ; Check for "exit" command
    mov esi, command
    mov edi, cmd_exit
    mov ecx, cmd_exit_len
    call compare_strings
    cmp eax, 0
    je exit_program
    
    ; Check for "create" command
    mov esi, command
    mov edi, cmd_create
    mov ecx, cmd_create_len
    call compare_strings
    cmp eax, 0
    je handle_create
    
    ; Check for "add" command
    mov esi, command
    mov edi, cmd_add
    mov ecx, cmd_add_len
    call compare_strings
    cmp eax, 0
    je handle_add
    
    ; Check for "post" command
    mov esi, command
    mov edi, cmd_post
    mov ecx, cmd_post_len
    call compare_strings
    cmp eax, 0
    je handle_post
    
    ; Check for "display" command
    mov esi, command
    mov edi, cmd_display
    mov ecx, cmd_display_len
    call compare_strings
    cmp eax, 0
    je handle_display
    
    ; Unknown command
    jmp bad_request

handle_create:
    ; Execute: ./create_user <id>
    mov dword [argv], create_prog
    mov eax, [arg_count]
    ; NULL terminate argv
    inc eax
    mov dword [argv + eax * 4], 0
    
    ; Fork and exec
    call fork_and_exec
    jmp main_loop

handle_add:
    ; Execute: ./add_friend <id> <friend>
    mov dword [argv], add_prog
    mov eax, [arg_count]
    inc eax
    mov dword [argv + eax * 4], 0
    
    call fork_and_exec
    jmp main_loop

handle_post:
    ; Execute: ./post_message <sender> <receiver> <message>
    mov dword [argv], post_prog
    mov eax, [arg_count]
    inc eax
    mov dword [argv + eax * 4], 0
    
    call fork_and_exec
    jmp main_loop

handle_display:
    ; Execute: ./display_wall <id>
    mov dword [argv], display_prog
    mov eax, [arg_count]
    inc eax
    mov dword [argv + eax * 4], 0
    
    call fork_and_exec
    jmp main_loop

bad_request:
    mov eax, 4
    mov ebx, 1
    mov ecx, error_msg
    mov edx, error_msg_len
    int 0x80
    jmp main_loop

exit_program:
    mov eax, 1
    xor ebx, ebx
    int 0x80

; ============================================
; Helper Functions
; ============================================

; Compare strings
; Input: esi = string1, edi = string2, ecx = length
; Output: eax = 0 if equal, non-zero if different
compare_strings:
    push esi
    push edi
    push ecx
    
compare_loop:
    cmp ecx, 0
    je compare_check_end
    
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne compare_not_equal
    
    inc esi
    inc edi
    dec ecx
    jmp compare_loop
    
compare_check_end:
    ; Check if string1 also ends here
    mov al, [esi]
    test al, al
    jnz compare_not_equal
    cmp al, 32          ; or space
    je compare_equal
    cmp al, 9           ; or tab
    je compare_equal
    
compare_equal:
    pop ecx
    pop edi
    pop esi
    xor eax, eax
    ret
    
compare_not_equal:
    pop ecx
    pop edi
    pop esi
    mov eax, 1
    ret

; Fork and execute program
; Input: argv array is set up with program and arguments
fork_and_exec:
    ; Fork
    mov eax, 2          ; sys_fork
    int 0x80
    
    cmp eax, 0
    jl fork_error       ; fork failed
    je child_process    ; we're in child
    
    ; Parent process - wait for child
    mov ebx, eax        ; child PID
    push ebx
    
wait_child:
    mov eax, 7          ; sys_waitpid
    pop ebx             ; child PID
    push ebx
    xor ecx, ecx        ; status pointer (we don't care)
    xor edx, edx        ; options
    int 0x80
    
    pop ebx
    
    ; Flush any output (just to be safe)
    ; Actually, let's not add anything here yet
    ret

child_process:
    ; Execute the program
    mov eax, 11         ; sys_execve
    mov ebx, [argv]     ; program path
    mov ecx, argv       ; argv array
    xor edx, edx        ; envp (NULL)
    int 0x80
    
    ; If execve returns, it failed
    ; Print error message
    push eax            ; save error code
    mov eax, 4
    mov ebx, 2          ; stderr
    mov ecx, exec_error
    mov edx, exec_error_len
    int 0x80
    pop eax
    
    mov eax, 1
    mov ebx, 1
    int 0x80

fork_error:
    ret