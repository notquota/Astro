bits 64

pci_config_read32:
    push rdx

    mov eax, edi
    and eax, 0x00FFFFFC
    or eax, 0x80000000

    mov dx, 0x0CF8
    out dx, eax

    mov dx, 0x0CFC
    in eax, dx

    pop rdx
    ret

pci_network_scan:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov byte [pci_ethernet_found], 0
    mov byte [pci_network_other_found], 0
    mov dword [pci_ethernet_id], 0
    mov dword [pci_network_other_id], 0

    xor r12d, r12d

.bus:
    cmp r12d, 256
    jae .done

    xor r13d, r13d

.device:
    cmp r13d, 32
    jae .next_bus

    xor r14d, r14d

.function:
    cmp r14d, 8
    jae .next_device

    mov r15d, r12d
    shl r15d, 16

    mov eax, r13d
    shl eax, 11
    or r15d, eax

    mov eax, r14d
    shl eax, 8
    or r15d, eax

    mov edi, r15d
    call pci_config_read32

    cmp ax, 0xFFFF
    je .absent

    mov ebx, eax

    mov edi, r15d
    or edi, 0x08
    call pci_config_read32

    shr eax, 16

    cmp ax, 0x0200
    je .ethernet

    cmp ax, 0x0280
    je .network_other

    jmp .advance

.ethernet:
    cmp byte [pci_ethernet_found], 0
    jne .advance

    mov byte [pci_ethernet_found], 1
    mov [pci_ethernet_id], ebx
    mov [pci_ethernet_bdf], r15d
    jmp .advance

.network_other:
    cmp byte [pci_network_other_found], 0
    jne .advance

    mov byte [pci_network_other_found], 1
    mov [pci_network_other_id], ebx
    mov [pci_network_other_bdf], r15d

.advance:
    cmp r14d, 0
    jne .next_function

    mov edi, r15d
    or edi, 0x0C
    call pci_config_read32

    test eax, 0x00800000
    jz .next_device

.next_function:
    inc r14d
    jmp .function

.absent:
    cmp r14d, 0
    je .next_device

    jmp .next_function

.next_device:
    inc r13d
    jmp .device

.next_bus:
    inc r12d
    jmp .bus

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

align 8

pci_ethernet_found:
    db 0

pci_network_other_found:
    db 0

align 4

pci_ethernet_id:
    dd 0

pci_network_other_id:
    dd 0

pci_ethernet_bdf:
    dd 0

pci_network_other_bdf:
    dd 0