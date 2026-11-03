bits 64

process_initialize:
    push rdi
    push rcx
    push rax

    lea rdi, [process_table]
    mov ecx, CORE_PROCESS_COUNT * CORE_RECORD_SIZE / 8
    xor eax, eax
    rep stosq

    pop rax
    pop rcx
    pop rdi
    ret

process_create:
    xor ecx, ecx

.search:
    cmp ecx, CORE_PROCESS_COUNT
    jae .failed

    mov eax, ecx
    shl rax, 5
    lea rdx, [process_table + rax]

    cmp qword [rdx], CORE_STATE_FREE
    je .found

    inc ecx
    jmp .search

.found:
    mov qword [rdx], CORE_STATE_READY
    mov [rdx + 8], rdi

    lea eax, [rcx + 1]
    mov [rdx + 16], rax
    ret

.failed:
    xor eax, eax
    ret

process_stop:
    test rdi, rdi
    jz .failed

    cmp rdi, CORE_PROCESS_COUNT
    ja .failed

    lea rax, [rdi - 1]
    shl rax, 5
    lea rdx, [process_table + rax]

    cmp qword [rdx], CORE_STATE_FREE
    je .failed

    mov qword [rdx], CORE_STATE_STOPPED
    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

process_get:
    test rdi, rdi
    jz .failed

    cmp rdi, CORE_PROCESS_COUNT
    ja .failed

    lea rax, [rdi - 1]
    shl rax, 5
    lea rax, [process_table + rax]
    ret

.failed:
    xor eax, eax
    ret

align 16

process_table:
    times CORE_PROCESS_COUNT * CORE_RECORD_SIZE db 0