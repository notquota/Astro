bits 64

%define ARP_PACKET_BUFFER 0x67000
%define ARP_PACKET_SIZE 28
%define ARP_PADDED_SIZE 46

arp_initialize:
    mov byte [arp_found], 0
    mov dword [arp_peer_ip], 0
    mov dword [arp_pending_ip], 0
    mov dword [arp_peer_mac], 0
    mov word [arp_peer_mac + 4], 0
    ret

arp_request:
    push rbx
    push r12

    mov r12, rdi

    cmp dword [ipv4_address], 0
    je .failed

    mov eax, [r12]
    test eax, eax
    jz .failed

    mov [arp_pending_ip], eax
    mov byte [arp_found], 0

    mov rdi, ARP_PACKET_BUFFER
    xor eax, eax
    mov ecx, ARP_PADDED_SIZE
    cld
    rep stosb

    mov word [ARP_PACKET_BUFFER], 0x0100
    mov word [ARP_PACKET_BUFFER + 2], 0x0008

    mov byte [ARP_PACKET_BUFFER + 4], 6
    mov byte [ARP_PACKET_BUFFER + 5], 4

    mov word [ARP_PACKET_BUFFER + 6], 0x0100

    mov rdi, ARP_PACKET_BUFFER + 8
    lea rsi, [pcnet_mac]
    mov ecx, 6
    rep movsb

    mov eax, [ipv4_address]
    mov [ARP_PACKET_BUFFER + 14], eax

    mov eax, [r12]
    mov [ARP_PACKET_BUFFER + 24], eax

    lea rdi, [ethernet_broadcast]
    mov esi, 0x0806
    mov rdx, ARP_PACKET_BUFFER
    mov ecx, ARP_PADDED_SIZE
    call ethernet_send

    test eax, eax
    jz .failed

    mov eax, 1
    jmp .done

.failed:
    mov dword [arp_pending_ip], 0
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

arp_receive:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi

    cmp r13, ARP_PACKET_SIZE
    jb .done

    cmp word [r12], 0x0100
    jne .done

    cmp word [r12 + 2], 0x0008
    jne .done

    cmp byte [r12 + 4], 6
    jne .done

    cmp byte [r12 + 5], 4
    jne .done

    cmp dword [ipv4_address], 0
    je .done

    mov eax, [r12 + 24]
    cmp eax, [ipv4_address]
    jne .done

    mov ax, [r12 + 6]

    cmp ax, 0x0200
    je .record

    cmp ax, 0x0100
    je .reply

    jmp .done

.record:
    mov eax, [arp_pending_ip]
    test eax, eax
    jz .done

    cmp eax, [r12 + 14]
    jne .done

    mov [arp_peer_ip], eax

    lea rsi, [r12 + 8]
    lea rdi, [arp_peer_mac]
    mov ecx, 6
    cld
    rep movsb

    mov byte [arp_found], 1
    mov dword [arp_pending_ip], 0
    jmp .done

.reply:
    mov rdi, ARP_PACKET_BUFFER
    xor eax, eax
    mov ecx, ARP_PADDED_SIZE
    cld
    rep stosb

    mov word [ARP_PACKET_BUFFER], 0x0100
    mov word [ARP_PACKET_BUFFER + 2], 0x0008

    mov byte [ARP_PACKET_BUFFER + 4], 6
    mov byte [ARP_PACKET_BUFFER + 5], 4

    mov word [ARP_PACKET_BUFFER + 6], 0x0200

    mov rdi, ARP_PACKET_BUFFER + 8
    lea rsi, [pcnet_mac]
    mov ecx, 6
    rep movsb

    mov eax, [ipv4_address]
    mov [ARP_PACKET_BUFFER + 14], eax

    mov rdi, ARP_PACKET_BUFFER + 18
    lea rsi, [r12 + 8]
    mov ecx, 6
    rep movsb

    mov eax, [r12 + 14]
    mov [ARP_PACKET_BUFFER + 24], eax

    lea rdi, [r12 + 8]
    mov esi, 0x0806
    mov rdx, ARP_PACKET_BUFFER
    mov ecx, ARP_PADDED_SIZE
    call ethernet_send

.done:
    pop r13
    pop r12
    pop rbx
    ret

arp_found:
    db 0

align 4

arp_peer_ip:
    dd 0

arp_pending_ip:
    dd 0

arp_peer_mac:
    times 6 db 0