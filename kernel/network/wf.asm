bits 64

%define WF_IDLE 0
%define WF_DNS_WAIT 1
%define WF_TCP_WAIT 2
%define WF_HTTP_WAIT 3
%define WF_COMPLETE 4
%define WF_FAILED 5

wf_initialize:
    mov byte [wf_state], WF_IDLE
    ret

wf_start:
    cmp byte [wf_state], WF_DNS_WAIT
    je .failed

    cmp byte [wf_state], WF_TCP_WAIT
    je .failed

    cmp byte [wf_state], WF_HTTP_WAIT
    je .failed

    cmp byte [tcp_state], TCP_ARP_WAIT
    je .failed

    cmp byte [tcp_state], TCP_SYN_SENT
    je .failed

    cmp byte [tcp_state], TCP_ESTABLISHED
    je .failed

    cmp byte [tcp_state], TCP_HTTP_SENT
    je .failed

    call dns_start

    test eax, eax
    jz .failed

    mov byte [wf_state], WF_DNS_WAIT

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

wf_poll:
    cmp byte [wf_state], WF_DNS_WAIT
    je .dns

    cmp byte [wf_state], WF_TCP_WAIT
    je .tcp

    cmp byte [wf_state], WF_HTTP_WAIT
    je .http

    ret

.dns:
    cmp byte [dns_state], DNS_FAILED
    je .failed

    cmp byte [dns_state], DNS_RESOLVED
    jne .done

    mov eax, [dns_result]
    test eax, eax
    jz .failed

    mov [tcp_target_ip], eax
    mov word [tcp_remote_port], 80

    lea rdi, [dns_hostname]
    call tcp_store_host

    test eax, eax
    jz .failed

    call tcp_begin

    test eax, eax
    jz .failed

    mov byte [tcp_auto_get], 1
    mov byte [wf_state], WF_TCP_WAIT

    mov rsi, wf_connecting_message
    call commands_print
    jmp .done

.tcp:
    cmp byte [tcp_state], TCP_ERROR
    je .failed

    cmp byte [tcp_state], TCP_CLOSED
    je .finished

    cmp byte [tcp_state], TCP_HTTP_SENT
    jne .done

    mov byte [wf_state], WF_HTTP_WAIT
    jmp .done

.http:
    cmp byte [tcp_state], TCP_ERROR
    je .failed

    cmp byte [tcp_state], TCP_CLOSED
    jne .done

.finished:
    mov byte [wf_state], WF_COMPLETE

    cmp dword [tcp_output_left], 2048
    je .no_response

    mov rsi, wf_complete_message
    call commands_print
    jmp .done

.no_response:
    mov rsi, wf_closed_message
    call commands_error
    jmp .done

.failed:
    mov byte [wf_state], WF_FAILED

    mov rsi, wf_failed_message
    call commands_error

.done:
    ret

wf_state:
    db WF_IDLE

wf_connecting_message:
    db "DNS complete. Opening HTTP connection...", 0

wf_complete_message:
    db "HTTP connection finished. Response data received.", 0

wf_closed_message:
    db "Connection closed without response data.", 0

wf_failed_message:
    db "Web fetch failed. Check DNS, ARP and TCP status.", 0