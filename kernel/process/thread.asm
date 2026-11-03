bits 64

thread_initialize:
    push rdi
    push rcx
    push rax

    lea rdi, [thread_table]
    mov ecx, CORE_THREAD_COUNT * CORE_RECORD_SIZE / 8
    xor eax, eax
    rep stosq

    pop rax
    pop rcx
    pop rdi
    ret

thread_create:
    xor ecx, ecx

.search:
    cmp ecx, CORE_THREAD_COUNT
    jae .failed

    mov eax, ecx
    shl rax, 5
    lea rdx, [thread_table + rax]

    cmp qword [rdx], CORE_STATE_FREE
    je .found

    inc ecx
    jmp .search

.found:
    mov qword [rdx], CORE_STATE_READY
    mov [rdx + 8], rdi
    mov [rdx + 16], rsi

    lea eax, [rcx + 1]
    ret

.failed:
    xor eax, eax
    ret

thread_stop:
    test rdi, rdi
    jz .failed

    cmp rdi, CORE_THREAD_COUNT
    ja .failed

    lea rax, [rdi - 1]
    shl rax, 5
    lea rdx, [thread_table + rax]

    cmp qword [rdx], CORE_STATE_FREE
    je .failed

    mov qword [rdx], CORE_STATE_STOPPED

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

thread_get:
    test rdi, rdi
    jz .failed

    cmp rdi, CORE_THREAD_COUNT
    ja .failed

    lea rax, [rdi - 1]
    shl rax, 5
    lea rax, [thread_table + rax]

    ret

.failed:
    xor eax, eax
    ret

align 16

thread_table:
    times CORE_THREAD_COUNT * CORE_RECORD_SIZE db 0