
bits 64

service_registry_initialize:
    lea rdi, [service_table]
    mov ecx, CORE_SERVICE_COUNT
    xor eax, eax
    rep stosq
    ret

service_register:
    cmp rdi, CORE_SERVICE_COUNT
    jae .failed

    lea rax, [service_table + rdi * 8]
    mov [rax], rsi

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

service_lookup:
    cmp rdi, CORE_SERVICE_COUNT
    jae .failed

    lea rax, [service_table + rdi * 8]
    mov rax, [rax]
    ret

.failed:
    xor eax, eax
    ret

align 16

service_table:
    times CORE_SERVICE_COUNT dq 0
