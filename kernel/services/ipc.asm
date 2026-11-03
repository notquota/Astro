
bits 64

ipc_initialize:
    mov qword [ipc_head], 0
    mov qword [ipc_tail], 0
    mov qword [ipc_count], 0
    ret

ipc_send:
    cmp qword [ipc_count], CORE_MESSAGE_COUNT
    jae .failed

    mov rax, [ipc_tail]
    imul rax, 24

    lea r8, [ipc_queue + rax]

    mov [r8], rdi
    mov [r8 + 8], rsi
    mov [r8 + 16], rdx

    inc qword [ipc_tail]

    cmp qword [ipc_tail], CORE_MESSAGE_COUNT
    jb .count

    mov qword [ipc_tail], 0

.count:
    inc qword [ipc_count]

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

ipc_receive:
    cmp qword [ipc_count], 0
    je .empty

    mov rax, [ipc_head]
    imul rax, 24

    lea r8, [ipc_queue + rax]

    mov rdi, [r8]
    mov rsi, [r8 + 8]
    mov rdx, [r8 + 16]

    inc qword [ipc_head]

    cmp qword [ipc_head], CORE_MESSAGE_COUNT
    jb .count

    mov qword [ipc_head], 0

.count:
    dec qword [ipc_count]

    clc
    ret

.empty:
    stc
    ret

ipc_head:
    dq 0

ipc_tail:
    dq 0

ipc_count:
    dq 0

align 16

ipc_queue:
    times CORE_MESSAGE_COUNT * 24 db 0
