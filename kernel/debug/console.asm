
bits 64

debug_console_line:
    mov rax, rdi
    imul rax, 160
    add rax, VGA_BASE

    mov rdi, rax
    jmp kernel_console_write

debug_console_hex64:
    push rax
    push rcx
    push rdx

    mov ecx, 16

.next:
    mov rdx, rax
    shr rdx, 60

    mov dl, [debug_hex_digits + rdx]
    mov dh, bl

    mov [rdi], dx
    add rdi, 2

    shl rax, 4

    dec ecx
    jnz .next

    pop rdx
    pop rcx
    pop rax
    ret

debug_hex_digits:
    db "0123456789ABCDEF"