bits 64

%define NETDEV_ETHERNET 0
%define NETDEV_WIFI 1
%define NETDEV_SLOTS 2
%define NETDEV_SIZE 64

%define NETDEV_PRESENT 0
%define NETDEV_LINK 1
%define NETDEV_MAC 2
%define NETDEV_TX 8
%define NETDEV_POLL 16
%define NETDEV_CONTEXT 24
%define NETDEV_TX_PACKETS 32
%define NETDEV_RX_PACKETS 40
%define NETDEV_TX_ERRORS 48

%define NETDEV_LINK_DOWN 0
%define NETDEV_LINK_UP 1
%define NETDEV_NONE 0xFF

%define NETDEV_FRAME_MIN 14
%define NETDEV_FRAME_MAX 1518

netdev_initialize:
    cld

    mov byte [netdev_active], NETDEV_NONE
    mov qword [netdev_receive_callback], 0

    lea rdi, [netdev_table]

    xor eax, eax
    mov ecx, NETDEV_SLOTS * NETDEV_SIZE / 8

    rep stosq
    ret

netdev_get:
    cmp edi, NETDEV_SLOTS
    jae .failed

    mov eax, edi
    shl rax, 6

    lea rax, [netdev_table + rax]

    cmp byte [rax + NETDEV_PRESENT], 1
    jne .failed

    ret

.failed:
    xor eax, eax
    ret

netdev_register:
    cmp edi, NETDEV_SLOTS
    jae .failed

    test rsi, rsi
    jz .failed

    test rdx, rdx
    jz .failed

    mov eax, edi
    shl rax, 6

    lea r10, [netdev_table + rax]

    cmp byte [r10 + NETDEV_PRESENT], 0
    jne .failed

    mov ax, [rsi]
    mov [r10 + NETDEV_MAC], ax

    mov eax, [rsi + 2]
    mov [r10 + NETDEV_MAC + 2], eax

    mov [r10 + NETDEV_TX], rdx
    mov [r10 + NETDEV_POLL], rcx
    mov [r10 + NETDEV_CONTEXT], r8

    mov qword [r10 + NETDEV_TX_PACKETS], 0
    mov qword [r10 + NETDEV_RX_PACKETS], 0
    mov qword [r10 + NETDEV_TX_ERRORS], 0

    mov byte [r10 + NETDEV_LINK], NETDEV_LINK_DOWN
    mov byte [r10 + NETDEV_PRESENT], 1

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

netdev_unregister:
    call netdev_get

    test rax, rax
    jz .failed

    cmp byte [netdev_active], dil
    jne .clear

    mov byte [netdev_active], NETDEV_NONE

.clear:
    cld

    mov rdi, rax
    xor eax, eax
    mov ecx, NETDEV_SIZE / 8

    rep stosq

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

netdev_set_link:
    call netdev_get

    test rax, rax
    jz .failed

    xor edx, edx
    test esi, esi
    setnz dl

    mov [rax + NETDEV_LINK], dl

    test dl, dl
    jnz .success

    cmp byte [netdev_active], dil
    jne .success

    mov byte [netdev_active], NETDEV_NONE

.success:
    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

netdev_select:
    call netdev_get

    test rax, rax
    jz .failed

    cmp byte [rax + NETDEV_LINK], NETDEV_LINK_UP
    jne .failed

    mov [netdev_active], dil

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

netdev_get_active:
    movzx edi, byte [netdev_active]
    jmp netdev_get

netdev_set_receive:
    mov [netdev_receive_callback], rdi

    mov eax, 1
    ret

netdev_send:
    push r12

    test rdi, rdi
    jz .failed

    cmp rsi, NETDEV_FRAME_MIN
    jb .failed

    cmp rsi, NETDEV_FRAME_MAX
    ja .failed

    movzx eax, byte [netdev_active]

    cmp eax, NETDEV_SLOTS
    jae .failed

    shl rax, 6
    lea r12, [netdev_table + rax]

    cmp byte [r12 + NETDEV_PRESENT], 1
    jne .failed

    cmp byte [r12 + NETDEV_LINK], NETDEV_LINK_UP
    jne .failed

    mov rax, [r12 + NETDEV_TX]
    test rax, rax
    jz .failed

    mov rdx, [r12 + NETDEV_CONTEXT]
    call rax

    test eax, eax
    jz .tx_failed

    inc qword [r12 + NETDEV_TX_PACKETS]

    mov eax, 1
    jmp .done

.tx_failed:
    inc qword [r12 + NETDEV_TX_ERRORS]

.failed:
    xor eax, eax

.done:
    pop r12
    ret

netdev_receive:
    push rbx
    push r12
    push r13

    mov r13, rsi
    mov rbx, rdx

    test r13, r13
    jz .failed

    cmp rbx, NETDEV_FRAME_MIN
    jb .failed

    cmp rbx, NETDEV_FRAME_MAX
    ja .failed

    movzx eax, byte [netdev_active]
    cmp eax, edi
    jne .failed

    call netdev_get

    test rax, rax
    jz .failed

    mov r12, rax

    cmp byte [r12 + NETDEV_LINK], NETDEV_LINK_UP
    jne .failed

    mov rax, [netdev_receive_callback]
    test rax, rax
    jz .failed

    mov rdi, r13
    mov rsi, rbx

    call rax

    inc qword [r12 + NETDEV_RX_PACKETS]

    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

netdev_poll:
    push rbx
    push r12
    push r13

    xor r12d, r12d

.next:
    cmp r12d, NETDEV_SLOTS
    jae .done

    mov rax, r12
    shl rax, 6

    lea r13, [netdev_table + rax]

    cmp byte [r13 + NETDEV_PRESENT], 1
    jne .advance

    mov rax, [r13 + NETDEV_POLL]
    test rax, rax
    jz .advance

    mov rdi, [r13 + NETDEV_CONTEXT]
    call rax

.advance:
    inc r12d
    jmp .next

.done:
    pop r13
    pop r12
    pop rbx
    ret

netdev_get_mac:
    call netdev_get

    test rax, rax
    jz .failed

    lea rax, [rax + NETDEV_MAC]
    ret

.failed:
    xor eax, eax
    ret

netdev_get_link:
    call netdev_get

    test rax, rax
    jz .failed

    movzx eax, byte [rax + NETDEV_LINK]
    ret

.failed:
    xor eax, eax
    ret

netdev_get_tx_count:
    call netdev_get

    test rax, rax
    jz .failed

    mov rax, [rax + NETDEV_TX_PACKETS]
    ret

.failed:
    xor eax, eax
    ret

netdev_get_rx_count:
    call netdev_get

    test rax, rax
    jz .failed

    mov rax, [rax + NETDEV_RX_PACKETS]
    ret

.failed:
    xor eax, eax
    ret

netdev_get_error_count:
    call netdev_get

    test rax, rax
    jz .failed

    mov rax, [rax + NETDEV_TX_ERRORS]
    ret

.failed:
    xor eax, eax
    ret

netdev_active:
    db NETDEV_NONE

align 8

netdev_receive_callback:
    dq 0

align 16

netdev_table:
    times NETDEV_SLOTS * NETDEV_SIZE db 0