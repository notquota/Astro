
bits 64

kernel_selftest_run:
    mov qword [selftest_passed], 0
    mov qword [selftest_failed], 0

    call selftest_physical
    call selftest_heap
    call selftest_process
    call selftest_thread
    call selftest_scheduler
    call selftest_service
    call selftest_events
    call selftest_ipc
    call selftest_virtual

    cmp qword [selftest_failed], 0
    jne .failed

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

selftest_pass:
    inc qword [selftest_passed]
    ret

selftest_fail:
    inc qword [selftest_failed]
    ret

selftest_physical:
    call memory_physical_allocate
    test rax, rax
    jz .failed

    mov rdi, rax
    call memory_physical_free

    cmp eax, 1
    jne .failed

    jmp selftest_pass

.failed:
    jmp selftest_fail

selftest_heap:
    mov rdi, 64
    call memory_heap_allocate

    test rax, rax
    jz .failed

    test rax, 15
    jnz .failed

    jmp selftest_pass

.failed:
    jmp selftest_fail

selftest_process:
    mov rdi, 0x1234
    call process_create

    test rax, rax
    jz .failed

    mov rdi, rax
    call process_stop

    cmp eax, 1
    jne .failed

    jmp selftest_pass

.failed:
    jmp selftest_fail

selftest_thread:
    mov rdi, selftest_callback
    xor esi, esi
    call thread_create

    test rax, rax
    jz .failed

    mov rdi, rax
    call thread_get

    test rax, rax
    jz .failed

    cmp qword [rax + 8], selftest_callback
    jne .failed

    jmp selftest_pass

.failed:
    jmp selftest_fail

selftest_scheduler:
    mov qword [selftest_callback_count], 0

    call scheduler_step

    cmp eax, 1
    jne .failed

    cmp qword [selftest_callback_count], 1
    jne .failed

    jmp selftest_pass

.failed:
    jmp selftest_fail

selftest_callback:
    inc qword [selftest_callback_count]
    ret

selftest_service:
    mov rdi, 1
    mov rsi, selftest_callback
    call service_register

    cmp eax, 1
    jne .failed

    mov rdi, 1
    call service_lookup

    cmp rax, selftest_callback
    jne .failed

    jmp selftest_pass

.failed:
    jmp selftest_fail

selftest_events:
    mov rdi, 0x55
    mov rsi, 0xAA
    call event_push

    cmp eax, 1
    jne .failed

    call event_pop
    jc .failed

    cmp rax, 0x55
    jne .failed

    cmp rsi, 0xAA
    jne .failed

    jmp selftest_pass

.failed:
    jmp selftest_fail

selftest_ipc:
    mov rdi, 1
    mov rsi, 2
    mov rdx, 0x12345678
    call ipc_send

    cmp eax, 1
    jne .failed

    call ipc_receive
    jc .failed

    cmp rdi, 1
    jne .failed

    cmp rsi, 2
    jne .failed

    cmp rdx, 0x12345678
    jne .failed

    jmp selftest_pass

.failed:
    jmp selftest_fail

selftest_virtual:
    mov rdi, VGA_BASE
    call memory_virtual_translate

    cmp rax, VGA_BASE
    jne .failed

    jmp selftest_pass

.failed:
    jmp selftest_fail

align 8

selftest_passed:
    dq 0

selftest_failed:
    dq 0

selftest_callback_count:
    dq 0