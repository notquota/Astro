
bits 64

memory_heap_initialize:
    mov qword [heap_position], 0
    ret

memory_heap_allocate:
    test rdi, rdi
    jz .failed

    mov rax, [heap_position]

    add rax, 15
    jc .failed

    and rax, -16

    mov rdx, rax
    add rdx, rdi
    jc .failed

    cmp rdx, CORE_HEAP_SIZE
    ja .failed

    mov [heap_position], rdx

    lea rdx, [heap_storage]
    add rax, rdx

    ret

.failed:
    xor eax, eax
    ret

memory_heap_reset:
    mov qword [heap_position], 0
    ret

align 16

heap_position:
    dq 0

align 16

heap_storage:
    times CORE_HEAP_SIZE db 0