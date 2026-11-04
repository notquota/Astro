bits 64

%define PCNET_INIT_BLOCK 0x60000
%define PCNET_RX_RING 0x60100
%define PCNET_TX_RING 0x60200
%define PCNET_RX_BUFFERS 0x61000
%define PCNET_TX_BUFFERS 0x63000

%define PCNET_BUFFER_SIZE 1536
%define PCNET_RX_COUNT 4
%define PCNET_TX_COUNT 2

pcnet_pci_write32:
    push rdx

    mov eax, edi
    and eax, 0x00FFFFFC
    or eax, 0x80000000

    mov dx, 0x0CF8
    out dx, eax

    mov eax, esi
    mov dx, 0x0CFC
    out dx, eax

    pop rdx
    ret

pcnet_csr_read:
    mov dx, [pcnet_io_base]
    add dx, 0x14
    mov eax, edi
    out dx, eax

    mov dx, [pcnet_io_base]
    add dx, 0x10
    in eax, dx
    and eax, 0xFFFF
    ret

pcnet_csr_write:
    mov dx, [pcnet_io_base]
    add dx, 0x14
    mov eax, edi
    out dx, eax

    mov dx, [pcnet_io_base]
    add dx, 0x10
    mov eax, esi
    out dx, eax
    ret

pcnet_bcr_write:
    mov dx, [pcnet_io_base]
    add dx, 0x14
    mov eax, edi
    out dx, eax

    mov dx, [pcnet_io_base]
    add dx, 0x1C
    mov eax, esi
    out dx, eax
    ret

pcnet_initialize:
    push rbx
    push r12
    push r13
    push r14

    mov byte [pcnet_ready], 0
    mov byte [pcnet_netdev_ready], 0
    mov dword [pcnet_error], 0
    mov dword [pcnet_rx_index], 0
    mov dword [pcnet_tx_index], 0
    mov qword [pcnet_rx_packets], 0
    mov qword [pcnet_tx_packets], 0

    mov eax, [pci_ethernet_id]

    cmp eax, 0x20001022
    je .supported

    cmp eax, 0x20011022
    je .supported

    mov dword [pcnet_error], 1
    jmp .failed

.supported:
    mov edi, [pci_ethernet_bdf]
    or edi, 0x10
    call pci_config_read32

    test eax, 1
    jz .invalid_bar

    and eax, 0xFFFFFFFC
    test eax, eax
    jz .invalid_bar

    cmp eax, 0x0000FFE0
    ja .invalid_bar

    mov [pcnet_io_base], ax

    mov edi, [pci_ethernet_bdf]
    or edi, 0x04
    call pci_config_read32

    or eax, 0x00000005

    mov esi, eax
    mov edi, [pci_ethernet_bdf]
    or edi, 0x04
    call pcnet_pci_write32

    mov dx, [pcnet_io_base]
    add dx, 0x18
    in eax, dx

    mov dx, [pcnet_io_base]
    add dx, 0x14
    in ax, dx

    mov ecx, 1000

.reset_wait:
    pause
    dec ecx
    jnz .reset_wait

    xor eax, eax
    mov dx, [pcnet_io_base]
    add dx, 0x10
    out dx, eax

    xor r12d, r12d

.read_mac:
    mov dx, [pcnet_io_base]
    add dx, r12w

    in al, dx
    mov [pcnet_mac + r12], al

    inc r12
    cmp r12, 6
    jb .read_mac

    mov rdi, PCNET_INIT_BLOCK
    xor eax, eax
    mov ecx, 0x300 / 8
    rep stosq

    mov word [PCNET_INIT_BLOCK], 0
    mov word [PCNET_INIT_BLOCK + 2], 0x1020

    lea rsi, [pcnet_mac]
    mov rdi, PCNET_INIT_BLOCK + 4
    mov ecx, 6
    rep movsb

    mov dword [PCNET_INIT_BLOCK + 20], PCNET_RX_RING
    mov dword [PCNET_INIT_BLOCK + 24], PCNET_TX_RING

    xor r12d, r12d

.rx_setup:
    mov rax, r12
    shl rax, 4
    lea rbx, [rax + PCNET_RX_RING]

    mov rax, r12
    imul rax, PCNET_BUFFER_SIZE
    add rax, PCNET_RX_BUFFERS

    mov [rbx], eax
    mov word [rbx + 4], 0xFA00
    mov word [rbx + 6], 0x8000
    mov dword [rbx + 8], 0
    mov dword [rbx + 12], 0

    inc r12d
    cmp r12d, PCNET_RX_COUNT
    jb .rx_setup

    xor r12d, r12d

.tx_setup:
    mov rax, r12
    shl rax, 4
    lea rbx, [rax + PCNET_TX_RING]

    mov rax, r12
    imul rax, PCNET_BUFFER_SIZE
    add rax, PCNET_TX_BUFFERS

    mov [rbx], eax
    mov word [rbx + 4], 0
    mov word [rbx + 6], 0
    mov dword [rbx + 8], 0
    mov dword [rbx + 12], 0

    inc r12d
    cmp r12d, PCNET_TX_COUNT
    jb .tx_setup

    mov edi, 20
    mov esi, 2
    call pcnet_bcr_write

    mov edi, 1
    mov esi, PCNET_INIT_BLOCK & 0xFFFF
    call pcnet_csr_write

    mov edi, 2
    mov esi, PCNET_INIT_BLOCK >> 16
    call pcnet_csr_write

    mov edi, 3
    xor esi, esi
    call pcnet_csr_write

    mov edi, 0
    mov esi, 1
    call pcnet_csr_write

    mov r13d, 5000000

.wait_init:
    xor edi, edi
    call pcnet_csr_read

    test eax, 0x0800
    jnz .init_failed

    test eax, 0x0100
    jnz .start

    pause
    dec r13d
    jnz .wait_init

.init_failed:
    mov dword [pcnet_error], 3
    jmp .failed

.start:
    xor edi, edi
    mov esi, 0x0102
    call pcnet_csr_write

    mov byte [pcnet_ready], 1

    call pcnet_netdev_register

    mov eax, 1
    jmp .done

.invalid_bar:
    mov dword [pcnet_error], 2

.failed:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

pcnet_netdev_register:
    xor edi, edi
    lea rsi, [pcnet_mac]
    lea rdx, [rel pcnet_send_frame]
    lea rcx, [rel pcnet_poll]
    xor r8d, r8d
    call netdev_register

    test eax, eax
    jz .failed

    xor edi, edi
    mov esi, 1
    call netdev_set_link

    test eax, eax
    jz .cleanup

    xor edi, edi
    call netdev_select

    test eax, eax
    jz .cleanup

    lea rdi, [rel ethernet_receive]
    call netdev_set_receive

    test eax, eax
    jz .cleanup

    mov byte [pcnet_netdev_ready], 1

    mov eax, 1
    ret

.cleanup:
    xor edi, edi
    call netdev_unregister

.failed:
    mov byte [pcnet_netdev_ready], 0
    xor eax, eax
    ret

pcnet_send_frame:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi

    cmp byte [pcnet_ready], 1
    jne .failed

    cmp r13, 14
    jb .failed

    cmp r13, 1514
    ja .failed

    mov eax, [pcnet_tx_index]
    shl eax, 4

    lea rbx, [rax + PCNET_TX_RING]

    test word [rbx + 6], 0x8000
    jnz .failed

    mov edi, [rbx]
    mov rsi, r12
    mov rcx, r13
    cld
    rep movsb

    mov eax, r13d
    neg eax
    and eax, 0x0FFF
    or eax, 0xF000

    mov [rbx + 4], ax

    mov dword [rbx + 8], 0
    mov dword [rbx + 12], 0

    sfence

    mov word [rbx + 6], 0x8300

    mov eax, [pcnet_tx_index]
    inc eax
    and eax, PCNET_TX_COUNT - 1
    mov [pcnet_tx_index], eax

    xor edi, edi
    mov esi, 8
    call pcnet_csr_write

    inc qword [pcnet_tx_packets]

    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

pcnet_poll:
    push rbx
    push r12
    push r13

    cmp byte [pcnet_ready], 1
    jne .done

    mov r12d, PCNET_RX_COUNT

.next:
    mov eax, [pcnet_rx_index]
    shl eax, 4

    lea rbx, [rax + PCNET_RX_RING]

    test word [rbx + 6], 0x8000
    jnz .done

    movzx eax, word [rbx + 6]
    and eax, 0x4300
    cmp eax, 0x0300
    jne .rearm

    movzx r13d, word [rbx + 8]
    and r13d, 0x0FFF

    cmp r13d, 18
    jb .rearm

    cmp r13d, PCNET_BUFFER_SIZE
    ja .rearm

    sub r13d, 4

    mov edi, [rbx]
    mov esi, r13d

    call ethernet_receive

    inc qword [pcnet_rx_packets]

.rearm:
    mov word [rbx + 4], 0xFA00
    mov dword [rbx + 8], 0

    sfence

    mov word [rbx + 6], 0x8000

    mov eax, [pcnet_rx_index]
    inc eax
    and eax, PCNET_RX_COUNT - 1
    mov [pcnet_rx_index], eax

    dec r12d
    jnz .next

.done:
    pop r13
    pop r12
    pop rbx
    ret

pcnet_io_base:
    dw 0

pcnet_ready:
    db 0

pcnet_netdev_ready:
    db 0

align 4

pcnet_error:
    dd 0

pcnet_rx_index:
    dd 0

pcnet_tx_index:
    dd 0

align 8

pcnet_rx_packets:
    dq 0

pcnet_tx_packets:
    dq 0

pcnet_mac:
    times 6 db 0