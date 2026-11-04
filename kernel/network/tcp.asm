bits 64

%define TCP_TX_BUFFER 0x67C00
%define TCP_HTTP_BUFFER 0x67A00
%define TCP_PSEUDO_BUFFER 0x67F00

%define TCP_IDLE 0
%define TCP_ARP_WAIT 1
%define TCP_SYN_SENT 2
%define TCP_ESTABLISHED 3
%define TCP_HTTP_SENT 4
%define TCP_ERROR 5
%define TCP_CLOSED 6

tcp_initialize:
    mov byte [tcp_state], TCP_IDLE
    mov byte [tcp_auto_get], 0
    mov byte [tcp_retry_count], 0
    mov byte [tcp_phase_seconds], 0
    mov word [tcp_poll_divider], 0
    mov dword [tcp_target_ip], 0
    mov dword [tcp_parse_ip], 0
    mov word [tcp_remote_port], 0
    mov word [tcp_local_port], 40999
    mov dword [tcp_seq], 0
    mov dword [tcp_ack], 0
    mov dword [tcp_output_left], 2048
    mov byte [tcp_pending_host], 0
    ret

tcp_checksum_add:
.next:
    cmp rsi, 2
    jb .last

    movzx eax, byte [rdi]
    shl eax, 8

    movzx ecx, byte [rdi + 1]
    or eax, ecx
    add edx, eax

    add rdi, 2
    sub rsi, 2
    jmp .next

.last:
    test rsi, rsi
    jz .done

    movzx eax, byte [rdi]
    shl eax, 8
    add edx, eax

.done:
    ret

tcp_checksum_finish:
    mov eax, edx
    mov ecx, eax
    shr ecx, 16
    and eax, 0xFFFF
    add eax, ecx

    mov ecx, eax
    shr ecx, 16
    add eax, ecx

    not ax
    xchg al, ah
    ret

tcp_send:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi
    mov r13, rsi
    mov r14d, edx

    cmp byte [pcnet_ready], 1
    jne .failed

    cmp r14d, 460
    ja .failed

    mov rdi, TCP_TX_BUFFER
    xor eax, eax
    mov ecx, 20
    cld
    rep stosb

    mov ax, [tcp_local_port]
    xchg al, ah
    mov [TCP_TX_BUFFER], ax

    mov ax, [tcp_remote_port]
    xchg al, ah
    mov [TCP_TX_BUFFER + 2], ax

    mov eax, [tcp_seq]
    bswap eax
    mov [TCP_TX_BUFFER + 4], eax

    mov eax, [tcp_ack]
    bswap eax
    mov [TCP_TX_BUFFER + 8], eax

    mov byte [TCP_TX_BUFFER + 12], 0x50
    mov [TCP_TX_BUFFER + 13], r12b
    mov word [TCP_TX_BUFFER + 14], 0x0020

    test r14d, r14d
    jz .payload_done

    mov rdi, TCP_TX_BUFFER + 20
    mov rsi, r13
    mov rcx, r14
    rep movsb

.payload_done:
    mov eax, [ipv4_address]
    mov [TCP_PSEUDO_BUFFER], eax

    mov eax, [tcp_target_ip]
    mov [TCP_PSEUDO_BUFFER + 4], eax

    mov byte [TCP_PSEUDO_BUFFER + 8], 0
    mov byte [TCP_PSEUDO_BUFFER + 9], 6

    lea eax, [r14 + 20]
    xchg al, ah
    mov [TCP_PSEUDO_BUFFER + 10], ax

    mov rdi, TCP_PSEUDO_BUFFER
    mov esi, 12
    xor edx, edx
    call tcp_checksum_add

    mov rdi, TCP_TX_BUFFER
    lea esi, [r14 + 20]
    call tcp_checksum_add

    call tcp_checksum_finish
    mov [TCP_TX_BUFFER + 16], ax

    lea rdi, [arp_peer_mac]
    mov esi, [tcp_target_ip]
    mov edx, 6
    mov rcx, TCP_TX_BUFFER
    lea r8, [r14 + 20]
    call ipv4_send_unicast

    jmp .done

.failed:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

tcp_begin:
    cmp byte [pcnet_ready], 1
    jne .failed

    cmp byte [dhcp_state], 3
    jne .failed

    cmp dword [ipv4_gateway], 0
    je .failed

    cmp byte [tcp_state], TCP_ARP_WAIT
    je .failed

    cmp byte [tcp_state], TCP_SYN_SENT
    je .failed

    cmp byte [tcp_state], TCP_ESTABLISHED
    je .failed

    cmp byte [tcp_state], TCP_HTTP_SENT
    je .failed

    mov byte [tcp_state], TCP_ARP_WAIT
    mov byte [tcp_auto_get], 0
    mov byte [tcp_retry_count], 0
    mov byte [tcp_phase_seconds], 0
    mov word [tcp_poll_divider], 0
    mov dword [tcp_output_left], 2048

    inc word [tcp_local_port]
    cmp word [tcp_local_port], 49000
    jb .port_ready

    mov word [tcp_local_port], 41000

.port_ready:
    call kernel_rtc_seconds
    mov [tcp_last_second], al

    lea rdi, [ipv4_gateway]
    call arp_request

    test eax, eax
    jz .failed_state

    mov eax, 1
    ret

.failed_state:
    mov byte [tcp_state], TCP_ERROR

.failed:
    xor eax, eax
    ret

tcp_timer_tick:
    inc word [tcp_poll_divider]
    test word [tcp_poll_divider], 0x03FF
    jnz .done

    call kernel_rtc_seconds

    cmp al, [tcp_last_second]
    je .done

    mov [tcp_last_second], al
    inc byte [tcp_phase_seconds]

.done:
    ret

tcp_poll:
    cmp byte [tcp_state], TCP_ARP_WAIT
    jb .done

    cmp byte [tcp_state], TCP_HTTP_SENT
    ja .done

    call tcp_timer_tick

    cmp byte [tcp_state], TCP_ARP_WAIT
    je .arp_wait

    cmp byte [tcp_state], TCP_SYN_SENT
    je .syn_wait

    cmp byte [tcp_state], TCP_HTTP_SENT
    je .http_wait

    ret

.arp_wait:
    cmp byte [arp_found], 1
    jne .arp_retry

    mov eax, [arp_peer_ip]
    cmp eax, [ipv4_gateway]
    jne .arp_retry

    rdtsc
    xor eax, edx
    xor eax, 0xA5730C21
    mov [tcp_seq], eax

    mov dword [tcp_ack], 0

    mov edi, 2
    xor esi, esi
    xor edx, edx
    call tcp_send

    test eax, eax
    jz .error

    inc dword [tcp_seq]

    mov byte [tcp_state], TCP_SYN_SENT
    mov byte [tcp_retry_count], 0
    mov byte [tcp_phase_seconds], 0

    mov rsi, tcp_syn_message
    call commands_print
    ret

.arp_retry:
    cmp byte [tcp_phase_seconds], 2
    jb .done

    mov byte [tcp_phase_seconds], 0

    cmp byte [tcp_retry_count], 3
    jae .timeout

    inc byte [tcp_retry_count]

    lea rdi, [ipv4_gateway]
    call arp_request

    test eax, eax
    jz .error

    ret

.syn_wait:
    cmp byte [tcp_phase_seconds], 3
    jb .done

    mov byte [tcp_phase_seconds], 0

    cmp byte [tcp_retry_count], 3
    jae .timeout

    inc byte [tcp_retry_count]

    dec dword [tcp_seq]

    mov edi, 2
    xor esi, esi
    xor edx, edx
    call tcp_send

    inc dword [tcp_seq]

    test eax, eax
    jz .error

    ret

.http_wait:
    cmp byte [tcp_phase_seconds], 10
    jb .done

    jmp .timeout

.timeout:
    mov byte [tcp_state], TCP_ERROR

    mov rsi, tcp_timeout_message
    call commands_error
    ret

.error:
    mov byte [tcp_state], TCP_ERROR

    mov rsi, tcp_error_message
    call commands_error

.done:
    ret

tcp_receive:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13, rsi
    mov r15d, edx

    cmp byte [tcp_state], TCP_SYN_SENT
    je .check

    cmp byte [tcp_state], TCP_ESTABLISHED
    je .check

    cmp byte [tcp_state], TCP_HTTP_SENT
    jne .done

.check:
    cmp r13, 20
    jb .done

    mov eax, [tcp_target_ip]
    cmp eax, r15d
    jne .done

    movzx eax, word [r12]
    xchg al, ah
    cmp ax, [tcp_remote_port]
    jne .done

    movzx eax, word [r12 + 2]
    xchg al, ah
    cmp ax, [tcp_local_port]
    jne .done

    movzx eax, byte [r12 + 12]
    shr eax, 4
    shl eax, 2

    cmp eax, 20
    jb .done

    cmp rax, r13
    ja .done

    mov r14, rax

    mov [TCP_PSEUDO_BUFFER], r15d

    mov eax, [ipv4_address]
    mov [TCP_PSEUDO_BUFFER + 4], eax

    mov byte [TCP_PSEUDO_BUFFER + 8], 0
    mov byte [TCP_PSEUDO_BUFFER + 9], 6

    mov eax, r13d
    xchg al, ah
    mov [TCP_PSEUDO_BUFFER + 10], ax

    mov rdi, TCP_PSEUDO_BUFFER
    mov esi, 12
    xor edx, edx
    call tcp_checksum_add

    mov rdi, r12
    mov rsi, r13
    call tcp_checksum_add

    call tcp_checksum_finish

    test ax, ax
    jnz .done

    test byte [r12 + 13], 4
    jnz .reset

    cmp byte [tcp_state], TCP_SYN_SENT
    je .syn_ack

    jmp .data

.syn_ack:
    mov al, [r12 + 13]
    and al, 0x12
    cmp al, 0x12
    jne .done

    mov eax, [r12 + 8]
    bswap eax
    cmp eax, [tcp_seq]
    jne .done

    mov eax, [r12 + 4]
    bswap eax
    inc eax
    mov [tcp_ack], eax

    mov edi, 0x10
    xor esi, esi
    xor edx, edx
    call tcp_send

    test eax, eax
    jz .reset

    mov byte [tcp_state], TCP_ESTABLISHED
    mov byte [tcp_phase_seconds], 0
    mov byte [tcp_retry_count], 0

    mov rsi, tcp_connected_message
    call commands_print

    cmp byte [tcp_auto_get], 1
    jne .done

    mov byte [tcp_auto_get], 0

    lea rdi, [tcp_pending_host]
    call tcp_http_get

    test eax, eax
    jz .http_error

    mov rsi, tcp_get_message
    call commands_print
    jmp .done

.http_error:
    mov rsi, tcp_error_message
    call commands_error
    jmp .done

.data:
    test byte [r12 + 13], 0x10
    jz .done

    mov eax, [r12 + 4]
    bswap eax

    cmp eax, [tcp_ack]
    jne .done

    mov rbx, r13
    sub rbx, r14

    test rbx, rbx
    jz .check_fin

    add dword [tcp_ack], ebx

    mov byte [tcp_phase_seconds], 0

    lea rdi, [r12 + r14]
    mov rsi, rbx
    call tcp_print_payload

.check_fin:
    test byte [r12 + 13], 1
    jz .ack_data

    inc dword [tcp_ack]

.ack_data:
    test rbx, rbx
    jnz .send_ack

    test byte [r12 + 13], 1
    jz .done

.send_ack:
    mov edi, 0x10
    xor esi, esi
    xor edx, edx
    call tcp_send

    test byte [r12 + 13], 1
    jz .done

    mov byte [tcp_state], TCP_CLOSED

    call shell_newline

    mov rsi, tcp_closed_message
    call commands_print
    jmp .done

.reset:
    mov byte [tcp_state], TCP_ERROR

    mov rsi, tcp_reset_message
    call commands_error

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

tcp_print_payload:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi
    xor ebx, ebx

.next:
    cmp rbx, r13
    jae .done

    cmp dword [tcp_output_left], 0
    je .done

    mov al, [r12 + rbx]

    cmp al, 13
    je .skip

    cmp al, 10
    je .write

    cmp al, 32
    jb .replace

    cmp al, 126
    jbe .write

.replace:
    mov al, '.'

.write:
    call shell_putc
    dec dword [tcp_output_left]

.skip:
    inc rbx
    jmp .next

.done:
    pop r13
    pop r12
    pop rbx
    ret

tcp_copy_string:
.next:
    mov al, [rsi]
    test al, al
    jz .done

    mov [rdi], al
    inc rdi
    inc rsi
    jmp .next

.done:
    ret

tcp_store_host:
    push rbx

    mov rsi, rdi
    lea rdi, [tcp_pending_host]
    xor ebx, ebx

.next:
    mov al, [rsi]
    test al, al
    jz .finish

    cmp al, 33
    jb .failed

    cmp al, 126
    ja .failed

    cmp ebx, 95
    jae .failed

    mov [rdi], al

    inc rsi
    inc rdi
    inc ebx
    jmp .next

.finish:
    test ebx, ebx
    jz .failed

    mov byte [rdi], 0

    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop rbx
    ret

tcp_http_get:
    push rbx
    push r12
    push r13
    push r14

    cmp byte [tcp_state], TCP_ESTABLISHED
    jne .failed

    mov r12, rdi

    xor r13d, r13d

.validate:
    mov al, [r12 + r13]

    test al, al
    jz .validated

    cmp al, 33
    jb .failed

    cmp al, 126
    ja .failed

    inc r13d
    cmp r13d, 95
    ja .failed

    jmp .validate

.validated:
    test r13d, r13d
    jz .failed

    mov rdi, TCP_HTTP_BUFFER
    mov rsi, tcp_http_prefix
    call tcp_copy_string

    mov rsi, r12
    call tcp_copy_string

    mov rsi, tcp_http_suffix
    call tcp_copy_string

    mov r14, rdi
    sub r14, TCP_HTTP_BUFFER

    cmp r14, 460
    ja .failed

    mov edi, 0x18
    mov rsi, TCP_HTTP_BUFFER
    mov rdx, r14
    call tcp_send

    test eax, eax
    jz .failed

    add dword [tcp_seq], r14d

    mov byte [tcp_state], TCP_HTTP_SENT
    mov byte [tcp_phase_seconds], 0
    mov dword [tcp_output_left], 2048

    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

tcp_parse_connect:
    push rbx
    push r12
    push r13
    push r14

    cmp byte [tcp_state], TCP_ARP_WAIT
    je .failed

    cmp byte [tcp_state], TCP_SYN_SENT
    je .failed

    cmp byte [tcp_state], TCP_ESTABLISHED
    je .failed

    cmp byte [tcp_state], TCP_HTTP_SENT
    je .failed

    mov r12, rdi
    xor r13d, r13d

    mov dword [tcp_parse_ip], 0
    mov word [tcp_parse_port], 80

.octet:
    xor ebx, ebx
    xor r14d, r14d

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

    inc r14d
    cmp r14d, 3
    ja .failed

    inc r12
    jmp .digit

.end_octet:
    test r14d, r14d
    jz .failed

    mov [tcp_parse_ip + r13], bl

    inc r13d
    cmp r13d, 4
    je .port

    cmp byte [r12], '.'
    jne .failed

    inc r12
    jmp .octet

.port:
    cmp byte [r12], 0
    je .begin

    cmp byte [r12], ' '
    jne .failed

    inc r12

    xor ebx, ebx
    xor r14d, r14d

.port_digit:
    movzx eax, byte [r12]
    test al, al
    jz .port_done

    cmp al, '0'
    jb .failed

    cmp al, '9'
    ja .failed

    sub eax, '0'

    imul ebx, ebx, 10
    add ebx, eax

    cmp ebx, 65535
    ja .failed

    inc r14d
    cmp r14d, 5
    ja .failed

    inc r12
    jmp .port_digit

.port_done:
    test r14d, r14d
    jz .failed

    test ebx, ebx
    jz .failed

    mov [tcp_parse_port], bx

.begin:
    mov eax, [tcp_parse_ip]
    mov [tcp_target_ip], eax

    mov ax, [tcp_parse_port]
    mov [tcp_remote_port], ax

    call tcp_begin
    jmp .done

.failed:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

tcp_fetch_command:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rdi
    xor ebx, ebx

.find_separator:
    mov al, [r13]

    test al, al
    jz .failed

    cmp al, ' '
    je .separator

    inc r13
    inc ebx

    cmp ebx, 15
    ja .failed

    jmp .find_separator

.separator:
    test ebx, ebx
    jz .failed

    mov byte [r13], 0

    lea rdi, [r13 + 1]
    call tcp_store_host

    test eax, eax
    jz .failed

    mov rdi, r12
    call tcp_parse_connect

    test eax, eax
    jz .failed

    mov byte [tcp_auto_get], 1

    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

tcp_command:
    push rbx

    mov rbx, rdi

    mov rdi, rbx
    mov rsi, tcp_command_status
    call fs_equal
    test eax, eax
    jnz .status

    mov rdi, rbx
    mov rsi, tcp_command_connect
    call network_prefix
    test eax, eax
    jnz .connect

    mov rdi, rbx
    mov rsi, tcp_command_fetch
    call network_prefix
    test eax, eax
    jnz .fetch

    mov rdi, rbx
    mov rsi, tcp_command_get
    call network_prefix
    test eax, eax
    jnz .get

.usage:
    mov rsi, tcp_usage
    call commands_print
    jmp .done

.connect:
    cmp byte [rbx + 7], ' '
    jne .usage

    lea rdi, [rbx + 8]
    cmp byte [rdi], 0
    je .usage

    call tcp_parse_connect

    test eax, eax
    jz .error

    mov rsi, tcp_connect_message
    call commands_print
    jmp .done

.fetch:
    cmp byte [rbx + 5], ' '
    jne .usage

    lea rdi, [rbx + 6]
    cmp byte [rdi], 0
    je .usage

    call tcp_fetch_command

    test eax, eax
    jz .error

    mov rsi, tcp_fetch_message
    call commands_print
    jmp .done

.get:
    cmp byte [rbx + 3], ' '
    jne .usage

    lea rdi, [rbx + 4]
    cmp byte [rdi], 0
    je .usage

    call tcp_http_get

    test eax, eax
    jz .error

    mov rsi, tcp_get_message
    call commands_print
    jmp .done

.status:
    movzx eax, byte [tcp_state]

    cmp eax, TCP_ARP_WAIT
    je .arp_wait

    cmp eax, TCP_SYN_SENT
    je .syn_wait

    cmp eax, TCP_ESTABLISHED
    je .established

    cmp eax, TCP_HTTP_SENT
    je .request_sent

    cmp eax, TCP_CLOSED
    je .closed

    cmp eax, TCP_ERROR
    je .error

    mov rsi, tcp_idle_message
    jmp .print

.arp_wait:
    mov rsi, tcp_arp_message
    jmp .print

.syn_wait:
    mov rsi, tcp_syn_wait_message
    jmp .print

.established:
    mov rsi, tcp_connected_message
    jmp .print

.request_sent:
    mov rsi, tcp_request_message
    jmp .print

.closed:
    mov rsi, tcp_closed_message

.print:
    call commands_print
    jmp .done

.error:
    mov rsi, tcp_error_message
    call commands_error

.done:
    pop rbx
    ret

tcp_state:
    db 0

tcp_auto_get:
    db 0

tcp_retry_count:
    db 0

tcp_phase_seconds:
    db 0

tcp_last_second:
    db 0

align 2

tcp_poll_divider:
    dw 0

tcp_remote_port:
    dw 0

tcp_local_port:
    dw 40999

tcp_parse_port:
    dw 80

align 4

tcp_target_ip:
    dd 0

tcp_parse_ip:
    dd 0

tcp_seq:
    dd 0

tcp_ack:
    dd 0

tcp_output_left:
    dd 2048

tcp_pending_host:
    times 96 db 0

tcp_command_connect:
    db "connect", 0

tcp_command_fetch:
    db "fetch", 0

tcp_command_get:
    db "get", 0

tcp_command_status:
    db "status", 0

tcp_http_prefix:
    db "GET / HTTP/1.0", 13, 10, "Host: ", 0

tcp_http_suffix:
    db 13, 10, "Connection: close", 13, 10, 13, 10, 0

tcp_usage:
    db "tcp connect <ip> [port]", 0

tcp_fetch_usage:
    db "tcp fetch <ip> <host>", 0

tcp_connect_message:
    db "Resolving gateway for TCP connection.", 0

tcp_fetch_message:
    db "Connecting. HTTP GET will send automatically.", 0

tcp_syn_message:
    db "TCP SYN sent.", 0

tcp_connected_message:
    db "TCP three-way handshake completed.", 0

tcp_get_message:
    db "HTTP GET request sent.", 0

tcp_idle_message:
    db "TCP idle.", 0

tcp_arp_message:
    db "TCP waiting for gateway ARP.", 0

tcp_syn_wait_message:
    db "TCP waiting for SYN-ACK.", 0

tcp_request_message:
    db "TCP connected. HTTP response pending.", 0

tcp_closed_message:
    db "TCP connection closed.", 0

tcp_reset_message:
    db "TCP connection reset.", 0

tcp_timeout_message:
    db "TCP connection timed out.", 0

tcp_error_message:
    db "TCP operation failed or connection unavailable.", 0