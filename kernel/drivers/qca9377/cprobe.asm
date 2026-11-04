bits 64

%ifidn __OUTPUT_FORMAT__,elf64

section .text

extern qca9377_probe_pci
extern qca9377_pci_read32

qca9377_cprobe_status:
    push rbx

    mov rbx, rsp
    and rsp, -16

    lea rdi, [rel qca9377_pci_read32]
    lea rsi, [rel qca9377_cprobe_device]

    call qca9377_probe_pci

    mov rsp, rbx

    cmp eax, 1
    je .found

    cmp eax, 0
    je .missing

    cmp eax, -2
    je .invalid_bar

    mov rsi, qca9377_cprobe_error
    call commands_error
    jmp .done

.found:
    mov rsi, qca9377_cprobe_detected
    call commands_print

    mov rsi, qca9377_cprobe_subsystem_label
    call shell_puts

    mov eax, [qca9377_cprobe_device + 4]
    call commands_hex

    mov rsi, qca9377_cprobe_revision_label
    call shell_puts

    movzx eax, byte [qca9377_cprobe_device + 24]
    call commands_hex

    mov rsi, qca9377_cprobe_bar_label
    call shell_puts

    mov rax, [qca9377_cprobe_device + 16]
    call commands_hex

    mov rsi, qca9377_cprobe_pending
    call commands_print
    jmp .done

.missing:
    mov rsi, qca9377_cprobe_missing
    call commands_print
    jmp .done

.invalid_bar:
    mov rsi, qca9377_cprobe_invalid_bar
    call commands_error

.done:
    pop rbx
    ret

qca9377_cprobe_detected:
    db "C DRIVER: QCA9377 detected.", 0

qca9377_cprobe_missing:
    db "C DRIVER: QCA9377 not present on PCI.", 0

qca9377_cprobe_error:
    db "C DRIVER: PCI probe failed.", 0

qca9377_cprobe_invalid_bar:
    db "C DRIVER: Invalid PCI memory BAR.", 0

qca9377_cprobe_pending:
    db "C DRIVER: Hardware initialization pending.", 0

qca9377_cprobe_subsystem_label:
    db "Subsystem: ", 0

qca9377_cprobe_revision_label:
    db "Revision: ", 0

qca9377_cprobe_bar_label:
    db "Physical BAR: ", 0

section .bss

align 8

qca9377_cprobe_device:
    resb 32

section .text

%endif