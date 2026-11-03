
bits 64

events_initialize:
    mov qword [event_head], 0
    mov qword [event_tail], 0
    mov qword [event_count], 0
    ret

event_push:
    cmp qword [event_count], CORE_EVENT_COUNT
    jae .failed

    mov rax, [event_tail]
    shl rax, 4

    lea rdx, [event_queue + rax]
    mov [rdx], rdi
    mov [rdx + 8], rsi

    inc qword [event_tail]

    cmp qword [event_tail], CORE_EVENT_COUNT
    jb .count

    mov qword [event_tail], 0

.count:
    inc qword [event_count]
    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

event_pop:
    cmp qword [event_count], 0
    je .empty

    mov rax, [event_head]
    shl rax, 4

    lea rdx, [event_queue + rax]

    mov rax, [rdx]
    mov rsi, [rdx + 8]

    inc qword [event_head]

    cmp qword [event_head], CORE_EVENT_COUNT
    jb .count

    mov qword [event_head], 0

.count:
    dec qword [event_count]
    clc
    ret

.empty:
    xor eax, eax
    xor esi, esi
    stc
    ret

event_head:
    dq 0

event_tail:
    dq 0

event_count:
    dq 0

align 16

event_queue:
    times CORE_EVENT_COUNT * 16 db 0
