
bits 64

kernel_initialize:
    cmp rdi, BOOT_INFO_ADDRESS
    jne .failed

    mov rax, [rdi]
    mov rcx, BOOT_INFO_MAGIC

    cmp rax, rcx
    jne .failed

    cmp qword [rdi + 8], KERNEL_LOAD_ADDRESS
    jne .failed

    cmp qword [rdi + 16], KERNEL_ENTRY_ADDRESS
    jne .failed

    cmp qword [rdi + 24], BOOT_MEMORY_MAP_ADDRESS
    jne .failed

    clc
    ret

.failed:
    stc
    ret
