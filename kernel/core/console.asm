
bits 64

kernel_console_clear:
    push rax
    push rcx
    push rdi

    mov rdi, VGA_BASE
    mov eax, 0x07200720
    mov ecx, 1000

    rep stosd

    pop rdi
    pop rcx
    pop rax
    ret

kernel_console_write:
    push rax
    push rsi
    push rdi

.next:
    lodsb
    test al, al
    jz .done

    mov ah, bl
    mov [rdi], ax

    add rdi, 2
    jmp .next

.done:
    pop rdi
    pop rsi
    pop rax
    ret
