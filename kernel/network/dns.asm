bits 64

%define DNS_UDP_BUFFER 0x68000
%define DNS_QUERY_BUFFER 0x68200
%define DNS_SOURCE_PORT 53053

%define DNS_IDLE 0
%define DNS_ARP_WAIT 1
%define DNS_WAITING 2
%define DNS_RESOLVED 3
%define DNS_FAILED 4

dns_initialize:
    mov byte [dns_state], DNS_IDLE
    mov byte [dns_retry_count], 0
    mov byte [dns_elapsed], 0
    mov byte [dns_reported], 0
    mov word [dns_poll_counter], 0
    mov word [dns_query_length], 0
    mov dword [dns_result], 0
    mov byte [dns_hostname], 0
    ret

dns_start:
    push rbx
    push r12
    push r13
    push r14

    cmp byte [dns_state], DNS_ARP_WAIT
    je .busy

    cmp byte [dns_state], DNS_WAITING
    je .busy

    mov r12, rdi
    xor r13d, r13d
    xor r14d, r14d

.validate:
    mov al, [r12 + r13]
    test al, al
    jz .validated

    cmp r13d, 95
    jae .failed

    cmp al, '.'
    je .dot

    cmp al, 'A'
    jb .check_alpha

    cmp al, 'Z'
    ja .check_alpha

    add al, 32

.check_alpha:
    cmp al, 'a'
    jb .check_digit

    cmp al, 'z'
    jbe .character

.check_digit:
    cmp al, '0'
    jb .check_hyphen

    cmp al, '9'
    jbe .character

.check_hyphen:
    cmp al, '-'
    jne .failed

.character:
    mov [dns_hostname + r13], al

    inc r13d
    inc r14d

    cmp r14d, 63
    ja .failed

    jmp .validate

.dot:
    test r14d, r14d
    jz .failed

    mov byte [dns_hostname + r13], '.'

    inc r13d
    xor r14d, r14d
    jmp .validate

.validated:
    test r13d, r13d
    jz .failed

    test r14d, r14d
    jz .failed

    mov byte [dns_hostname + r13], 0

    cmp byte [pcnet_ready], 1
    jne .failed

    cmp byte [dhcp_state], 3
    jne .failed

    cmp dword [ipv4_dns], 0
    je .failed

    cmp dword [ipv4_gateway], 0
    je .failed

    mov rdi, DNS_QUERY_BUFFER
    xor eax, eax
    mov ecx, 128
    cld
    rep stosd

    rdtsc
    mov [dns_transaction], ax
    mov [DNS_QUERY_BUFFER], ax

    mov word [DNS_QUERY_BUFFER + 2], 0x0001
    mov word [DNS_QUERY_BUFFER + 4], 0x0100

    lea rsi, [dns_hostname]
    mov rdi, DNS_QUERY_BUFFER + 12
    mov rbx, rdi

    inc rdi
    xor edx, edx

.encode:
    mov al, [rsi]
    test al, al
    jz .last_label

    cmp al, '.'
    je .next_label

    mov [rdi], al

    inc rdi
    inc rsi
    inc edx
    jmp .encode

.next_label:
    mov [rbx], dl

    mov rbx, rdi
    inc rdi
    inc rsi

    xor edx, edx
    jmp .encode

.last_label:
    mov [rbx], dl

    mov byte [rdi], 0
    inc rdi

    mov dword [rdi], 0x01000100
    add rdi, 4

    mov rax, rdi
    sub rax, DNS_QUERY_BUFFER

    mov [dns_query_length], ax

    mov dword [dns_result], 0
    mov byte [dns_reported], 0
    mov byte [dns_retry_count], 0
    mov byte [dns_elapsed], 0
    mov word [dns_poll_counter], 0
    mov byte [dns_state], DNS_ARP_WAIT

    call kernel_rtc_seconds
    mov [dns_last_second], al

    lea rdi, [ipv4_gateway]
    call arp_request

    test eax, eax
    jz .failed

    mov eax, 1
    jmp .done

.failed:
    mov byte [dns_state], DNS_FAILED
    mov byte [dns_reported], 1

.busy:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

dns_send:
    push r12
    push r13

    cmp byte [arp_found], 1
    jne .failed

    mov eax, [arp_peer_ip]
    cmp eax, [ipv4_gateway]
    jne .failed

    movzx r13d, word [dns_query_length]

    test r13d, r13d
    jz .failed

    mov rdi, DNS_UDP_BUFFER
    xor eax, eax
    mov ecx, 128
    cld
    rep stosd

    mov ax, DNS_SOURCE_PORT
    xchg al, ah
    mov [DNS_UDP_BUFFER], ax

    mov word [DNS_UDP_BUFFER + 2], 0x3500

    lea eax, [r13 + 8]
    xchg al, ah
    mov [DNS_UDP_BUFFER + 4], ax

    mov word [DNS_UDP_BUFFER + 6], 0

    mov rdi, DNS_UDP_BUFFER + 8
    mov rsi, DNS_QUERY_BUFFER
    mov rcx, r13
    rep movsb

    lea rdi, [arp_peer_mac]
    mov esi, [ipv4_dns]
    mov edx, 17
    mov rcx, DNS_UDP_BUFFER
    lea r8d, [r13 + 8]

    call ipv4_send_unicast
    jmp .done

.failed:
    xor eax, eax

.done:
    pop r13
    pop r12
    ret

dns_poll:
    cmp byte [dns_state], DNS_RESOLVED
    je .report_success

    cmp byte [dns_state], DNS_FAILED
    je .report_failure

    cmp byte [dns_state], DNS_ARP_WAIT
    je .arp

    cmp byte [dns_state], DNS_WAITING
    jne .done

    jmp .timer

.arp:
    cmp byte [arp_found], 1
    jne .timer

    mov eax, [arp_peer_ip]
    cmp eax, [ipv4_gateway]
    jne .timer

    call dns_send
    test eax, eax
    jz .set_failed

    mov byte [dns_state], DNS_WAITING
    mov byte [dns_elapsed], 0

    call kernel_rtc_seconds
    mov [dns_last_second], al
    jmp .done

.timer:
    inc word [dns_poll_counter]

    test word [dns_poll_counter], 0x03FF
    jnz .done

    call kernel_rtc_seconds

    cmp al, [dns_last_second]
    je .done

    mov [dns_last_second], al
    inc byte [dns_elapsed]

    cmp byte [dns_elapsed], 3
    jb .done

    mov byte [dns_elapsed], 0

    cmp byte [dns_retry_count], 2
    jae .set_failed

    inc byte [dns_retry_count]

    cmp byte [dns_state], DNS_ARP_WAIT
    jne .retry_query

    lea rdi, [ipv4_gateway]
    call arp_request

    test eax, eax
    jz .set_failed
    jmp .done

.retry_query:
    call dns_send

    test eax, eax
    jz .set_failed
    jmp .done

.report_success:
    cmp byte [dns_reported], 1
    je .done

    mov byte [dns_reported], 1

    mov rsi, dns_result_message
    call shell_puts

    lea rdi, [dns_result]
    call network_print_ipv4
    jmp .done

.report_failure:
    cmp byte [dns_reported], 1
    je .done

    mov byte [dns_reported], 1

    mov rsi, dns_failure_message
    call commands_error
    jmp .done

.set_failed:
    mov byte [dns_state], DNS_FAILED
    jmp .report_failure

.done:
    ret

dns_skip_name:
    push rbx

    mov rbx, rdx

.next:
    cmp rbx, rsi
    jae .failed

    movzx eax, byte [rdi + rbx]

    test eax, eax
    jz .terminator

    mov ecx, eax
    and ecx, 0xC0

    cmp ecx, 0xC0
    je .pointer

    test ecx, ecx
    jnz .failed

    cmp eax, 63
    ja .failed

    lea rcx, [rbx + rax + 1]

    cmp rcx, rsi
    ja .failed

    mov rbx, rcx
    jmp .next

.pointer:
    lea rcx, [rbx + 2]

    cmp rcx, rsi
    ja .failed

    movzx edx, byte [rdi + rbx + 1]

    and eax, 63
    shl eax, 8
    or eax, edx

    cmp rax, rsi
    jae .failed

    mov rax, rcx
    jmp .done

.terminator:
    lea rax, [rbx + 1]
    jmp .done

.failed:
    xor eax, eax

.done:
    pop rbx
    ret

dns_receive:
    push rbx
    push r12
    push r13
    push r14
    push r15

    cmp byte [dns_state], DNS_WAITING
    jne .done

    mov r12, rdi
    mov r13, rsi

    cmp r13, 12
    jb .done

    mov ax, [dns_transaction]
    cmp word [r12], ax
    jne .done

    test byte [r12 + 2], 0x80
    jz .done

    test byte [r12 + 2], 0x02
    jnz .failed

    mov al, [r12 + 3]
    and al, 0x0F
    jnz .failed

    cmp word [r12 + 4], 0x0100
    jne .failed

    movzx r15d, word [r12 + 6]
    rol r15w, 8

    test r15d, r15d
    jz .failed

    cmp r15d, 16
    ja .failed

    mov rdi, r12
    mov rsi, r13
    mov edx, 12
    call dns_skip_name

    test rax, rax
    jz .failed

    mov r14, rax

    lea rax, [r14 + 4]
    cmp rax, r13
    ja .failed

    cmp word [r12 + r14], 0x0100
    jne .failed

    cmp word [r12 + r14 + 2], 0x0100
    jne .failed

    add r14, 4

.answer:
    test r15d, r15d
    jz .failed

    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call dns_skip_name

    test rax, rax
    jz .failed

    mov r14, rax

    lea rax, [r14 + 10]
    cmp rax, r13
    ja .failed

    movzx ecx, word [r12 + r14 + 8]
    rol cx, 8

    lea rbx, [r14 + 10]
    add rbx, rcx

    cmp rbx, r13
    ja .failed

    cmp word [r12 + r14], 0x0100
    jne .next_answer

    cmp word [r12 + r14 + 2], 0x0100
    jne .next_answer

    cmp ecx, 4
    jne .next_answer

    mov eax, [r12 + r14 + 10]
    test eax, eax
    jz .next_answer

    mov [dns_result], eax
    mov byte [dns_state], DNS_RESOLVED
    jmp .done

.next_answer:
    mov r14, rbx

    dec r15d
    jmp .answer

.failed:
    mov byte [dns_state], DNS_FAILED

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

dns_state:
    db 0

dns_retry_count:
    db 0

dns_elapsed:
    db 0

dns_last_second:
    db 0

dns_reported:
    db 0

align 2

dns_poll_counter:
    dw 0

dns_transaction:
    dw 0

dns_query_length:
    dw 0

align 4

dns_result:
    dd 0

dns_hostname:
    times 96 db 0

dns_result_message:
    db "DNS resolved: ", 0

dns_failure_message:
    db "DNS resolution failed or timed out.", 0