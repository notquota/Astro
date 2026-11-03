
bits 64

scheduler_initialize:
    mov qword [scheduler_position], 0
    ret

scheduler_step:
    push rbx
    push r12

    xor r12d, r12d

.search:
    cmp r12d, CORE_THREAD_COUNT
    jae .idle

    mov rbx, [scheduler_position]
    inc rbx
    cmp rbx, CORE_THREAD_COUNT
    jb .index_ready

    xor ebx, ebx

.index_ready:
    mov [scheduler_position], rbx

    mov rax, rbx
    shl rax, 5
    lea rdx, [thread_table + rax]

    cmp qword [rdx], CORE_STATE_READY
    jne .next

    mov qword [rdx], CORE_STATE_RUNNING

    mov rdi, [rdx + 16]
    mov rax, [rdx + 8]

    test rax, rax
    jz .stop

    call rax

    mov rax, rbx
    shl rax, 5
    lea rdx, [thread_table + rax]

    cmp qword [rdx], CORE_STATE_RUNNING
    jne .success

    mov qword [rdx], CORE_STATE_READY
    jmp .success

.stop:
    mov qword [rdx], CORE_STATE_STOPPED

.success:
    mov eax, 1
    jmp .done

.next:
    inc r12d
    jmp .search

.idle:
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

scheduler_position:
    dq 0
