bits 64

%define ETHERNET_TX_BUFFER 0x64000

ethernet_send:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    mov r15, rcx

    cmp r15, 1500
    ja .failed

    mov rdi, ETHERNET_TX_BUFFER
    mov rsi, r12
    mov ecx, 6
    cld
    rep movsb

    lea rsi, [pcnet_mac]
    mov ecx, 6
    rep movsb

    mov ax, r13w
    xchg al, ah
    mov [ETHERNET_TX_BUFFER + 12], ax

    mov rdi, ETHERNET_TX_BUFFER + 14
    mov rsi, r14
    mov rcx, r15
    rep movsb

    mov rdi, ETHERNET_TX_BUFFER
    lea rsi, [r15 + 14]
    call pcnet_send_frame

    jmp .done

.failed:
    xor eax, eax

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

ethernet_receive:
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi

    cmp r13, 14
    jb .done

    mov ax, [r12 + 12]
    xchg al, ah

    cmp ax, 0x0806
    je .arp

    cmp ax, 0x0800
    je .ipv4

    jmp .done

.arp:
    lea rdi, [r12 + 14]
    lea rsi, [r13 - 14]
    call arp_receive
    jmp .done

.ipv4:
    lea rdi, [r12 + 14]
    lea rsi, [r13 - 14]
    call ipv4_receive

.done:
    pop r13
    pop r12
    ret

ethernet_broadcast:
    times 6 db 0xFF