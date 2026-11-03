bits 64

%define SHELL_INPUT_LIMIT 127

shell_initialize:
    mov dword [shell_cursor], 0
    mov byte [shell_color], 0x0F
    mov qword [shell_command_count], 0

    call keyboard_initialize
    call fs_initialize

    ret

shell_clear:
    push rax
    push rcx
    push rdi

    mov rdi, VGA_BASE
    mov eax, 0x07200720
    mov ecx, 1000

    rep stosd

    mov dword [shell_cursor], 0

    pop rdi
    pop rcx
    pop rax
    ret

shell_scroll:
    push rax
    push rcx
    push rsi
    push rdi

    mov rsi, VGA_BASE + 160
    mov rdi, VGA_BASE
    mov ecx, 960

    rep movsd

    mov eax, 0x07200720
    mov ecx, 40

    rep stosd

    mov dword [shell_cursor], 1920

    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

shell_putc:
    push rax
    push rcx
    push rdx
    push rdi

    cmp al, 10
    je .newline

    mov edx, [shell_cursor]

    cmp edx, 2000
    jb .write

    call shell_scroll
    mov edx, [shell_cursor]

.write:
    lea rdi, [VGA_BASE + rdx * 2]

    mov ah, [shell_color]
    mov [rdi], ax

    inc dword [shell_cursor]
    jmp .check

.newline:
    mov eax, [shell_cursor]
    xor edx, edx
    mov ecx, 80
    div ecx

    inc eax
    imul eax, 80

    mov [shell_cursor], eax

.check:
    cmp dword [shell_cursor], 2000
    jb .done

    call shell_scroll

.done:
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret

shell_puts:
    push rax
    push rsi

.next:
    lodsb
    test al, al
    jz .done

    call shell_putc
    jmp .next

.done:
    pop rsi
    pop rax
    ret

shell_newline:
    push rax

    mov al, 10
    call shell_putc

    pop rax
    ret

shell_readline:
    push rbx
    push r12
    push r13

    mov r12, rdi
    xor r13d, r13d

.read:
    call keyboard_wait

    cmp al, 13
    je .enter

    cmp al, 8
    je .backspace

    cmp al, 32
    jb .read

    cmp r13d, SHELL_INPUT_LIMIT
    jae .read

    mov [r12 + r13], al
    inc r13

    call shell_putc
    jmp .read

.backspace:
    test r13d, r13d
    jz .read

    dec r13

    cmp dword [shell_cursor], 0
    je .read

    dec dword [shell_cursor]

    mov edx, [shell_cursor]
    lea rdi, [VGA_BASE + rdx * 2]

    mov word [rdi], 0x0720
    jmp .read

.enter:
    mov byte [r12 + r13], 0

    call shell_newline

    mov rax, r13

    pop r13
    pop r12
    pop rbx
    ret

shell_execute:
    inc qword [shell_command_count]
    call commands_dispatch
    ret

shell_run:
    call shell_clear

    mov byte [shell_color], 0x0B
    mov rsi, shell_banner
    call shell_puts
    call shell_newline

    mov byte [shell_color], 0x07
    mov rsi, shell_welcome
    call shell_puts
    call shell_newline
    call shell_newline

.loop:
    mov byte [shell_color], 0x0B
    mov rsi, shell_prompt
    call shell_puts

    mov byte [shell_color], 0x0F
    lea rdi, [shell_line]
    call shell_readline

    cmp byte [shell_line], 0
    je .loop

    lea rdi, [shell_line]
    call shell_execute

    jmp .loop

shell_cursor:
    dd 0

shell_color:
    db 0x0F

shell_command_count:
    dq 0

shell_line:
    times SHELL_INPUT_LIMIT + 1 db 0

shell_banner:
    db "A5TR0 / SHELL", 0

shell_welcome:
    db "System ready. Type help for commands.", 0

shell_prompt:
    db "A5TR0> ", 0