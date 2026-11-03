
bits 64

memory_physical_initialize:
    mov word [physical_bitmap], 0
    ret

memory_physical_allocate:
    xor ecx, ecx

.search:
    cmp ecx, CORE_FRAME_COUNT
    jae .failed

    bt word [physical_bitmap], cx
    jnc .found

    inc ecx
    jmp .search

.found:
    bts word [physical_bitmap], cx

    mov eax, ecx
    shl rax, 12
    add rax, CORE_FRAME_BASE
    ret

.failed:
    xor eax, eax
    ret

memory_physical_free:
    cmp rdi, CORE_FRAME_BASE
    jb .failed

    mov rax, rdi
    sub rax, CORE_FRAME_BASE

    test rax, CORE_PAGE_SIZE - 1
    jnz .failed

    shr rax, 12
    cmp rax, CORE_FRAME_COUNT
    jae .failed

    btr word [physical_bitmap], ax
    jnc .failed

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

physical_bitmap:
    dw 0
