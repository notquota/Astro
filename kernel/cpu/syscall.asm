
bits 64

cpu_syscall_initialize:
    xor eax, eax
    ret

cpu_syscall_dispatch:
    mov rax, -38
    ret