bits 64

%define ICMP_PACKET_BUFFER 0x66800
%define ICMP_PACKET_SIZE 36

icmp_initialize:
    mov byte [icmp_state], 0
    mov dword [icmp_target], 0
    mov dword [icmp_reply_source], 0
    ret

icmp_start:
    push rbx

    mov rbx, rdi

    cmp byte [pcnet_ready], 1
    jne .failed

    cmp dword [ipv4_address], 0
    je .failed

    cmp dword [ipv4_gateway], 0
    je .failed

    mov rdi, rbx
    call icmp_parse_address
    test eax, eax
    jz .failed

    mov eax, [icmp_target]
    cmp eax, [ipv4_gateway]
    jne .unsupported

    mov byte [arp_found], 0
    mov byte [icmp_state], 1

    lea rdi, [icmp_target]
    call arp_request

    test eax, eax
    jz .failed

    mov eax, 1
    jmp .done

.unsupported:
    mov byte [icmp_state], 5
    xor eax, eax
    jmp .done

.failed:
    mov byte [icmp_state], 0
    xor eax, eax

.done:
    pop rbx
    ret

icmp_parse_address:
    push rbx
    push r12
    push r13

    mov r12, rdi
    xor r13d, r13d

.octet:
    xor ebx, ebx
    xor ecx, ecx

.digit:
    movzx eax, byte [r12]

    cmp al, '0'
    jb .end_octet

    cmp al, '9'
    ja .end_octet

    sub eax, '0'

    imul ebx, ebx, 10
    add ebx, eax

    cmp ebx, 255
    ja .failed

    inc ecx
    cmp ecx, 3
    ja .failed

    inc r12
    jmp .digit

.end_octet:
    test ecx, ecx
    jz .failed

    mov [icmp_target + r13], bl
    inc r13d

    cmp r13d, 4
    je .last

    cmp byte [r12], '.'
    jne .failed

    inc r12
    jmp .octet

.last:
    cmp byte [r12], 0
    jne .failed

    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

icmp_poll:
    cmp byte [icmp_state], 1
    je .resolve

    cmp byte [icmp_state], 3
    je .received

    ret

.resolve:
    cmp byte [arp_found], 1
    jne .done

    mov eax, [arp_peer_ip]
    cmp eax, [icmp_target]
    jne .done

    call icmp_send_echo

    test eax, eax
    jz .error

    mov byte [icmp_state], 2
    ret

.received:
    mov byte [icmp_state], 4

    mov rsi, icmp_reply_message
    call commands_print
    ret

.error:
    mov byte [icmp_state], 0

.done:
    ret

icmp_send_echo:
    push rbx
    push r12

    mov rdi, ICMP_PACKET_BUFFER
    xor eax, eax
    mov ecx, ICMP_PACKET_SIZE / 8
    cld
    rep stosq

    mov byte [ICMP_PACKET_BUFFER], 0x45
    mov word [ICMP_PACKET_BUFFER + 2], 0x2400
    mov word [ICMP_PACKET_BUFFER + 4], 0x7856

    mov byte [ICMP_PACKET_BUFFER + 8], 64
    mov byte [ICMP_PACKET_BUFFER + 9], 1

    mov eax, [ipv4_address]
    mov [ICMP_PACKET_BUFFER + 12], eax

    mov eax, [icmp_target]
    mov [ICMP_PACKET_BUFFER + 16], eax

    mov byte [ICMP_PACKET_BUFFER + 20], 8
    mov byte [ICMP_PACKET_BUFFER + 21], 0

    mov word [ICMP_PACKET_BUFFER + 24], 0x305A
    mov word [ICMP_PACKET_BUFFER + 26], 0x0100

    mov rax, 0x4F52545341355441
    mov [ICMP_PACKET_BUFFER + 28], rax

    mov rdi, ICMP_PACKET_BUFFER + 20
    mov ecx, 16
    call ipv4_checksum

    mov [ICMP_PACKET_BUFFER + 22], ax

    mov rdi, ICMP_PACKET_BUFFER
    mov ecx, 20
    call ipv4_checksum

    mov [ICMP_PACKET_BUFFER + 10], ax

    lea rdi, [arp_peer_mac]
    mov esi, 0x0800
    mov rdx, ICMP_PACKET_BUFFER
    mov ecx, ICMP_PACKET_SIZE
    call ethernet_send

    pop r12
    pop rbx
    ret

icmp_receive:
    cmp rsi, 8
    jb .done

    cmp byte [icmp_state], 2
    jne .done

    cmp byte [rdi], 0
    jne .done

    cmp byte [rdi + 1], 0
    jne .done

    cmp word [rdi + 4], 0x305A
    jne .done

    cmp word [rdi + 6], 0x0100
    jne .done

    mov eax, [icmp_target]
    cmp eax, [icmp_reply_source]
    jne .done

    mov byte [icmp_state], 3

.done:
    ret

icmp_state:
    db 0

align 4

icmp_target:
    dd 0

icmp_reply_source:
    dd 0

icmp_reply_message:
    db "ICMP Echo Reply received from gateway.", 0