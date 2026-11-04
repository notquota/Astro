bits 64

%define WIFI_PCI_MAX_DEVICES 8

wifi_pci_initialize:
    mov byte [wifi_pci_scanned], 0
    mov byte [wifi_pci_count], 0
    ret

wifi_pci_read_config:
    mov dx, 0xCF8
    out dx, eax

    mov dx, 0xCFC
    in eax, dx
    ret

wifi_pci_scan:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    cmp byte [wifi_pci_scanned], 1
    je .done

    mov byte [wifi_pci_scanned], 1
    mov byte [wifi_pci_count], 0

    xor r12d, r12d

.bus:
    xor r13d, r13d

.device:
    xor r14d, r14d

.function:
    mov eax, r12d
    shl eax, 16

    mov ecx, r13d
    shl ecx, 11
    or eax, ecx

    mov ecx, r14d
    shl ecx, 8
    or eax, ecx

    or eax, 0x80000000
    mov r15d, eax

    call wifi_pci_read_config

    cmp ax, 0xFFFF
    je .absent

    mov ebx, eax

    mov eax, r15d
    or eax, 0x08
    call wifi_pci_read_config

    mov ebp, eax

    mov ecx, eax
    shr ecx, 16

    cmp ecx, 0x0280
    je .found

    cmp ecx, 0x0D20
    je .found

    cmp ecx, 0x0D21
    je .found

    cmp ecx, 0x0D80
    jne .next_function

.found:
    movzx eax, byte [wifi_pci_count]

    cmp eax, WIFI_PCI_MAX_DEVICES
    jae .next_function

    shl eax, 4

    lea rdx, [wifi_pci_records + rax]

    mov [rdx], ebx
    mov [rdx + 4], ebp
    mov [rdx + 8], r15d
    mov dword [rdx + 12], 0

    inc byte [wifi_pci_count]
    jmp .next_function

.absent:
    test r14d, r14d
    jz .next_device

.next_function:
    inc r14d

    cmp r14d, 8
    jb .function

.next_device:
    inc r13d

    cmp r13d, 32
    jb .device

    inc r12d

    cmp r12d, 256
    jb .bus

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

wifi_pci_list:
    push rbx
    push r12
    push r13

    call wifi_pci_scan

    movzx r12d, byte [wifi_pci_count]

    test r12d, r12d
    jz .empty

    mov rsi, wifi_pci_header
    call commands_print

    xor r13d, r13d

.next:
    cmp r13d, r12d
    jae .done

    mov eax, r13d
    shl eax, 4

    lea rbx, [wifi_pci_records + rax]

    mov rsi, wifi_pci_id_label
    call shell_puts

    mov eax, [rbx]
    call commands_hex

    mov rsi, wifi_pci_class_label
    call shell_puts

    mov eax, [rbx + 4]
    shr eax, 16
    call commands_hex

    mov rsi, wifi_pci_address_label
    call shell_puts

    mov eax, [rbx + 8]
    and eax, 0x00FFFF00
    call commands_hex

    inc r13d
    jmp .next

.empty:
    mov rsi, wifi_pci_empty
    call commands_print

.done:
    pop r13
    pop r12
    pop rbx
    ret

wifi_pci_scanned:
    db 0

wifi_pci_count:
    db 0

align 8

wifi_pci_records:
    times WIFI_PCI_MAX_DEVICES * 16 db 0

wifi_pci_header:
    db "PCI wireless candidates:", 0

wifi_pci_id_label:
    db "Vendor/device: ", 0

wifi_pci_class_label:
    db "Class code: ", 0

wifi_pci_address_label:
    db "PCI address: ", 0

wifi_pci_empty:
    db "No PCI wireless candidates detected.", 0