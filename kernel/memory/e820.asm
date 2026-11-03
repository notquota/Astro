
bits 64

memory_e820_get:
    cmp rdx, rcx
    jae .invalid

    mov rax, rdx
    imul rax, 24
    add rax, rsi
    ret

.invalid:
    xor eax, eax
    ret

memory_e820_usable:
    mov rax, [rdi + 16]
    cmp eax, 1
    sete al
    movzx eax, al
    ret

memory_e820_end:
    mov rax, [rdi]
    add rax, [rdi + 8]
    ret
