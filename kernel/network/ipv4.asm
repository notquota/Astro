bits 64

%define IPV4_PACKET_BUFFER 0x65000
%define IPV4_MAX_PAYLOAD 1480
%define IPV4_MAX_DHCP 1472

ipv4_initialize:
    mov dword [ipv4_address], 0
    mov dword [ipv4_netmask], 0
    mov dword [ipv4_gateway], 0
    mov dword [ipv4_dns], 0
    mov word [ipv4_packet_id], 1
    ret

ipv4_checksum:
    push rbx

    xor edx, edx

.next:
    cmp ecx, 2
    jb .last

    movzx eax, byte [rdi]
    shl eax, 8

    movzx ebx, byte [rdi + 1]
    or eax, ebx

    add edx, eax

    add rdi, 2
    sub ecx, 2
    jmp .next

.last:
    test ecx, ecx
    jz .finish

    movzx eax, byte [rdi]
    shl eax, 8
    add edx, eax

.finish:
    mov eax, edx

    mov ebx, eax
    shr ebx, 16

    and eax, 0xFFFF
    add eax, ebx

    mov ebx, eax
    shr ebx, 16
    add eax, ebx

    not ax
    xchg al, ah

    pop rbx
    ret

ipv4_send_dhcp:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi

    test r12, r12
    jz .failed

    test r13, r13
    jz .failed

    cmp r13, IPV4_MAX_DHCP
    ja .failed

    mov rdi, IPV4_PACKET_BUFFER
    xor eax, eax
    mov ecx, 28
    cld
    rep stosb

    mov byte [IPV4_PACKET_BUFFER], 0x45

    lea eax, [r13 + 28]
    xchg al, ah
    mov [IPV4_PACKET_BUFFER + 2], ax

    mov ax, [ipv4_packet_id]
    inc word [ipv4_packet_id]
    xchg al, ah
    mov [IPV4_PACKET_BUFFER + 4], ax

    mov byte [IPV4_PACKET_BUFFER + 8], 64
    mov byte [IPV4_PACKET_BUFFER + 9], 17

    mov dword [IPV4_PACKET_BUFFER + 12], 0
    mov dword [IPV4_PACKET_BUFFER + 16], 0xFFFFFFFF

    mov rdi, IPV4_PACKET_BUFFER
    mov ecx, 20
    call ipv4_checksum
    mov [IPV4_PACKET_BUFFER + 10], ax

    mov word [IPV4_PACKET_BUFFER + 20], 0x4400
    mov word [IPV4_PACKET_BUFFER + 22], 0x4300

    lea eax, [r13 + 8]
    xchg al, ah
    mov [IPV4_PACKET_BUFFER + 24], ax

    mov word [IPV4_PACKET_BUFFER + 26], 0

    mov rdi, IPV4_PACKET_BUFFER + 28
    mov rsi, r12
    mov rcx, r13
    rep movsb

    lea rdi, [ethernet_broadcast]
    mov esi, 0x0800
    mov rdx, IPV4_PACKET_BUFFER
    lea rcx, [r13 + 28]
    call ethernet_send

    jmp .done

.failed:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

ipv4_send_unicast:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13d, esi
    mov r14d, edx
    mov r15, rcx
    mov ebx, r8d

    test r12, r12
    jz .failed

    test r15, r15
    jz .check_empty

    jmp .check_length

.check_empty:
    test ebx, ebx
    jnz .failed

.check_length:
    cmp ebx, IPV4_MAX_PAYLOAD
    ja .failed

    cmp byte [pcnet_ready], 1
    jne .failed

    mov rdi, IPV4_PACKET_BUFFER
    xor eax, eax
    mov ecx, 20
    cld
    rep stosb

    mov byte [IPV4_PACKET_BUFFER], 0x45

    lea eax, [rbx + 20]
    xchg al, ah
    mov [IPV4_PACKET_BUFFER + 2], ax

    mov ax, [ipv4_packet_id]
    inc word [ipv4_packet_id]
    xchg al, ah
    mov [IPV4_PACKET_BUFFER + 4], ax

    mov byte [IPV4_PACKET_BUFFER + 8], 64
    mov [IPV4_PACKET_BUFFER + 9], r14b

    mov eax, [ipv4_address]
    mov [IPV4_PACKET_BUFFER + 12], eax

    mov [IPV4_PACKET_BUFFER + 16], r13d

    mov rdi, IPV4_PACKET_BUFFER
    mov ecx, 20
    call ipv4_checksum
    mov [IPV4_PACKET_BUFFER + 10], ax

    test ebx, ebx
    jz .transmit

    mov rdi, IPV4_PACKET_BUFFER + 20
    mov rsi, r15
    mov ecx, ebx
    rep movsb

.transmit:
    mov rdi, r12
    mov esi, 0x0800
    mov rdx, IPV4_PACKET_BUFFER
    lea rcx, [rbx + 20]
    call ethernet_send
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

ipv4_receive:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rsi

    cmp r15, 20
    jb .done

    movzx eax, byte [r12]
    mov ecx, eax
    shr ecx, 4

    cmp ecx, 4
    jne .done

    and eax, 15

    cmp eax, 5
    jb .done

    shl eax, 2
    mov r14, rax

    cmp r14, r15
    ja .done

    movzx eax, word [r12 + 2]
    xchg al, ah

    cmp rax, r14
    jb .done

    cmp rax, r15
    ja .done

    mov r13, rax

    movzx eax, word [r12 + 6]
    xchg al, ah

    test ax, 0x3FFF
    jnz .done

    movzx eax, byte [r12 + 9]

    cmp eax, 1
    je .icmp

    cmp eax, 6
    je .tcp

    cmp eax, 17
    je .udp

    jmp .done

.icmp:
    mov rdi, r12
    add rdi, r14

    mov rsi, r13
    sub rsi, r14

    mov edx, [r12 + 12]
    call icmp_receive
    jmp .done

.tcp:
    mov rdi, r12
    add rdi, r14

    mov rsi, r13
    sub rsi, r14

    mov edx, [r12 + 12]
    call tcp_receive
    jmp .done

.udp:
    lea rax, [r14 + 8]
    cmp r13, rax
    jb .done

    mov rbx, r12
    add rbx, r14

    movzx eax, word [rbx + 4]
    xchg al, ah

    cmp eax, 8
    jb .done

    mov rcx, r13
    sub rcx, r14

    cmp rax, rcx
    ja .done

    sub eax, 8
    mov r15d, eax

    cmp word [rbx], 0x4300
    jne .dns_udp

    cmp word [rbx + 2], 0x4400
    jne .done

    lea rdi, [rbx + 8]
    mov esi, r15d
    call dhcp_receive
    jmp .done

.dns_udp:
    cmp word [rbx], 0x3500
    jne .done

    cmp word [rbx + 2], 0x3DCF
    jne .done

    mov eax, [r12 + 12]
    cmp eax, [ipv4_dns]
    jne .done

    lea rdi, [rbx + 8]
    mov esi, r15d
    call dns_receive

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

ipv4_address:
    dd 0

ipv4_netmask:
    dd 0

ipv4_gateway:
    dd 0

ipv4_dns:
    dd 0

ipv4_packet_id:
    dw 1