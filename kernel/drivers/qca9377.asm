bits 64

%define QCA9377_PCI_ID 0x0042168C
%define QCA9377_SUBSYSTEM_ID 0x08A611AD
%define QCA9377_REVISION_ID 0x31

qca9377_initialize:
    mov byte [qca9377_found], 0
    mov dword [qca9377_pci_address], 0
    mov dword [qca9377_subsystem], 0
    mov dword [qca9377_bar0], 0
    mov byte [qca9377_revision], 0
    ret

qca9377_probe:
    push rbx
    push r12
    push r13

    mov byte [qca9377_found], 0

    call wifi_pci_scan

    movzx r12d, byte [wifi_pci_count]
    xor r13d, r13d

.next:
    cmp r13d, r12d
    jae .not_found

    mov eax, r13d
    shl eax, 4

    lea rbx, [wifi_pci_records + rax]

    cmp dword [rbx], QCA9377_PCI_ID
    jne .advance

    mov eax, [rbx + 8]
    mov [qca9377_pci_address], eax

    or eax, 0x08
    call wifi_pci_read_config

    mov [qca9377_revision], al

    mov eax, [qca9377_pci_address]
    or eax, 0x2C
    call wifi_pci_read_config

    mov [qca9377_subsystem], eax

    mov eax, [qca9377_pci_address]
    or eax, 0x10
    call wifi_pci_read_config

    mov [qca9377_bar0], eax

    mov byte [qca9377_found], 1

    mov eax, 1
    jmp .done

.advance:
    inc r13d
    jmp .next

.not_found:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

qca9377_status:
    call qca9377_probe

    test eax, eax
    jz .missing

    mov rsi, qca9377_detected_message
    call commands_print

    mov rsi, qca9377_pci_message
    call shell_puts

    mov eax, [qca9377_pci_address]
    call commands_hex

    mov rsi, qca9377_subsystem_message
    call shell_puts

    mov eax, [qca9377_subsystem]
    call commands_hex

    mov rsi, qca9377_revision_message
    call shell_puts

    movzx eax, byte [qca9377_revision]
    call commands_hex

    mov rsi, qca9377_bar0_message
    call shell_puts

    mov eax, [qca9377_bar0]
    call commands_hex

    cmp dword [qca9377_subsystem], QCA9377_SUBSYSTEM_ID
    jne .different_board

    cmp byte [qca9377_revision], QCA9377_REVISION_ID
    jne .different_revision

    mov rsi, qca9377_exact_message
    call commands_print
    jmp .driver_pending

.different_board:
    mov rsi, qca9377_board_message
    call commands_print
    jmp .driver_pending

.different_revision:
    mov rsi, qca9377_revision_warning
    call commands_print

.driver_pending:
    mov rsi, qca9377_driver_pending_message
    call commands_print
    ret

.missing:
    mov rsi, qca9377_missing_message
    call commands_print
    ret

qca9377_found:
    db 0

qca9377_revision:
    db 0

align 4

qca9377_pci_address:
    dd 0

qca9377_subsystem:
    dd 0

qca9377_bar0:
    dd 0

qca9377_detected_message:
    db "Qualcomm Atheros QCA9377 detected.", 0

qca9377_pci_message:
    db "PCI configuration address: ", 0

qca9377_subsystem_message:
    db "Subsystem ID: ", 0

qca9377_revision_message:
    db "PCI revision: ", 0

qca9377_bar0_message:
    db "PCI BAR0: ", 0

qca9377_exact_message:
    db "Target board and revision matched.", 0

qca9377_board_message:
    db "QCA9377 detected with a different subsystem.", 0

qca9377_revision_warning:
    db "QCA9377 detected with a different revision.", 0

qca9377_driver_pending_message:
    db "Hardware initialization not implemented.", 0

qca9377_missing_message:
    db "QCA9377 PCI adapter not detected.", 0