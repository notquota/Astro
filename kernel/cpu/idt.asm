
bits 64

cpu_idt_initialize:
    push rax
    push rcx
    push rdx
    push rsi
    push rdi

    lea rsi, [cpu_exception_table]
    lea rdi, [cpu_idt]

    xor ecx, ecx

.next:
    mov rax, [rsi + rcx * 8]

    mov word [rdi], ax
    mov word [rdi + 2], 0x08
    mov byte [rdi + 4], 0
    mov byte [rdi + 5], 0x8E

    shr rax, 16
    mov word [rdi + 6], ax

    shr rax, 16
    mov dword [rdi + 8], eax

    mov dword [rdi + 12], 0

    add rdi, 16
    inc ecx

    cmp ecx, 32
    jb .next

    lidt [cpu_idtr]

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

align 16

cpu_idt:
    times 256 * 16 db 0

cpu_idtr:
    dw 256 * 16 - 1
    dq cpu_idt