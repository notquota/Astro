bits 64

%define DHCP_PACKET_BUFFER 0x66000
%define DHCP_PACKET_SIZE 300

dhcp_initialize:
    mov byte [dhcp_state], 0
    mov byte [dhcp_message_type], 0

    mov dword [dhcp_offer_ip], 0
    mov dword [dhcp_server], 0
    mov dword [dhcp_mask], 0
    mov dword [dhcp_router], 0
    mov dword [dhcp_dns], 0
    ret

dhcp_start:
    call dhcp_initialize
    call ipv4_initialize

    cmp byte [pcnet_ready], 1
    jne .failed

    mov byte [dhcp_state], 1

    mov edi, 1
    call dhcp_emit

    test eax, eax
    jz .failed

    mov eax, 1
    ret

.failed:
    mov byte [dhcp_state], 4
    xor eax, eax
    ret

dhcp_emit:
    push rbx
    push r12

    mov r12d, edi

    mov rdi, DHCP_PACKET_BUFFER
    xor eax, eax
    mov ecx, DHCP_PACKET_SIZE
    cld
    rep stosb

    mov byte [DHCP_PACKET_BUFFER], 1
    mov byte [DHCP_PACKET_BUFFER + 1], 1
    mov byte [DHCP_PACKET_BUFFER + 2], 6

    mov dword [DHCP_PACKET_BUFFER + 4], 0x010070A5
    mov word [DHCP_PACKET_BUFFER + 10], 0x0080

    mov rdi, DHCP_PACKET_BUFFER + 28
    lea rsi, [pcnet_mac]
    mov ecx, 6
    rep movsb

    mov dword [DHCP_PACKET_BUFFER + 236], 0x63538263

    mov rbx, DHCP_PACKET_BUFFER + 240

    mov word [rbx], 0x0135
    mov [rbx + 2], r12b
    add rbx, 3

    cmp r12d, 3
    jne .options

    mov word [rbx], 0x0432

    mov eax, [dhcp_offer_ip]
    mov [rbx + 2], eax
    add rbx, 6

    mov word [rbx], 0x0436

    mov eax, [dhcp_server]
    mov [rbx + 2], eax
    add rbx, 6

.options:
    mov word [rbx], 0x0437
    mov dword [rbx + 2], 0x33060301
    add rbx, 6

    mov byte [rbx], 255

    mov rdi, DHCP_PACKET_BUFFER
    mov esi, DHCP_PACKET_SIZE
    call ipv4_send_dhcp

    pop r12
    pop rbx
    ret

dhcp_receive:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi
    mov r13, rsi

    cmp r13, 240
    jb .done

    cmp byte [r12], 2
    jne .done

    cmp byte [r12 + 1], 1
    jne .done

    cmp byte [r12 + 2], 6
    jne .done

    cmp dword [r12 + 4], 0x010070A5
    jne .done

    cmp dword [r12 + 236], 0x63538263
    jne .done

    lea rdi, [r12 + 28]
    lea rsi, [pcnet_mac]
    mov ecx, 6
    repe cmpsb
    jne .done

    mov byte [dhcp_message_type], 0
    mov rbx, 240

.option:
    cmp rbx, r13
    jae .parsed

    movzx eax, byte [r12 + rbx]

    cmp eax, 255
    je .parsed

    test eax, eax
    jz .padding

    lea rdx, [rbx + 2]
    cmp rdx, r13
    ja .parsed

    movzx ecx, byte [r12 + rbx + 1]

    lea rdx, [rbx + rcx + 2]
    cmp rdx, r13
    ja .parsed

    cmp eax, 53
    je .message_type

    cmp eax, 54
    je .server

    cmp eax, 1
    je .mask

    cmp eax, 3
    je .router

    cmp eax, 6
    je .dns

    jmp .advance

.message_type:
    cmp ecx, 1
    jb .advance

    mov al, [r12 + rbx + 2]
    mov [dhcp_message_type], al
    jmp .advance

.server:
    cmp ecx, 4
    jb .advance

    mov eax, [r12 + rbx + 2]
    mov [dhcp_server], eax
    jmp .advance

.mask:
    cmp ecx, 4
    jb .advance

    mov eax, [r12 + rbx + 2]
    mov [dhcp_mask], eax
    jmp .advance

.router:
    cmp ecx, 4
    jb .advance

    mov eax, [r12 + rbx + 2]
    mov [dhcp_router], eax
    jmp .advance

.dns:
    cmp ecx, 4
    jb .advance

    mov eax, [r12 + rbx + 2]
    mov [dhcp_dns], eax

.advance:
    mov rbx, rdx
    jmp .option

.padding:
    inc rbx
    jmp .option

.parsed:
    cmp byte [dhcp_message_type], 6
    je .nak

    cmp byte [dhcp_state], 1
    je .consider_offer

    cmp byte [dhcp_state], 2
    je .consider_ack

    jmp .done

.consider_offer:
    cmp byte [dhcp_message_type], 2
    jne .done

    mov eax, [r12 + 16]
    test eax, eax
    jz .done

    mov [dhcp_offer_ip], eax

    cmp dword [dhcp_server], 0
    je .done

    mov byte [dhcp_state], 2

    mov edi, 3
    call dhcp_emit

    test eax, eax
    jnz .done

    mov byte [dhcp_state], 4
    jmp .done

.consider_ack:
    cmp byte [dhcp_message_type], 5
    jne .done

    mov eax, [r12 + 16]
    test eax, eax
    jnz .have_ip

    mov eax, [dhcp_offer_ip]

.have_ip:
    test eax, eax
    jz .done

    mov [ipv4_address], eax

    mov eax, [dhcp_mask]
    mov [ipv4_netmask], eax

    mov eax, [dhcp_router]
    mov [ipv4_gateway], eax

    mov eax, [dhcp_dns]
    mov [ipv4_dns], eax

    mov byte [dhcp_state], 3
    jmp .done

.nak:
    mov byte [dhcp_state], 4

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

dhcp_state:
    db 0

dhcp_message_type:
    db 0

align 4

dhcp_offer_ip:
    dd 0

dhcp_server:
    dd 0

dhcp_mask:
    dd 0

dhcp_router:
    dd 0

dhcp_dns:
    dd 0