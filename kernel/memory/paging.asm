bits 64

memory_paging_enabled:
    mov rax, cr0

    bt rax, 31
    setc al
    movzx eax, al

    ret

memory_paging_root:
    mov rax, cr3
    mov rdx, 0x000FFFFFFFFFF000
    and rax, rdx

    ret

memory_paging_invalidate:
    invlpg [rdi]
    ret

memory_paging_reload:
    mov rax, cr3
    mov cr3, rax

    ret