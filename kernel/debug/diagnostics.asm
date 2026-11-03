
bits 64

debug_diagnostics_run:
    mov rax, cr0
    bt rax, 31
    jnc .failed

    mov rax, cr4
    bt rax, 5
    jnc .failed

    mov ecx, 0xC0000080
    rdmsr

    bt eax, 10
    jnc .failed

    sidt [debug_idtr_snapshot]

    mov rax, [debug_idtr_snapshot + 2]
    mov rdx, cpu_idt
    cmp rax, rdx
    jne .failed

    mov eax, 1
    ret

.failed:
    xor eax, eax
    ret

debug_exception_report:
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx

    call kernel_console_clear

    mov rdi, 1
    mov rsi, debug_exception_title
    mov bl, 0x0C
    call debug_console_line

    mov rdi, 3
    mov rsi, debug_exception_vector
    mov bl, 0x0F
    call debug_console_line

    mov rax, r12
    mov rdi, VGA_BASE + 3 * 160 + 22 * 2
    mov bl, 0x0E
    call debug_console_hex64

    mov rdi, 4
    mov rsi, debug_exception_code
    mov bl, 0x0F
    call debug_console_line

    mov rax, r13
    mov rdi, VGA_BASE + 4 * 160 + 22 * 2
    mov bl, 0x0E
    call debug_console_hex64

    mov rdi, 5
    mov rsi, debug_exception_rip
    mov bl, 0x0F
    call debug_console_line

    mov rax, r14
    mov rdi, VGA_BASE + 5 * 160 + 22 * 2
    mov bl, 0x0E
    call debug_console_hex64

    mov rdi, 7
    mov rsi, debug_exception_halted
    mov bl, 0x0C
    call debug_console_line

    ret

align 8

debug_idtr_snapshot:
    times 10 db 0

debug_exception_title:
    db "A5TR0 / KERNEL EXCEPTION", 0

debug_exception_vector:
    db "EXCEPTION VECTOR:     ", 0

debug_exception_code:
    db "ERROR CODE:           ", 0

debug_exception_rip:
    db "INSTRUCTION POINTER:  ", 0

debug_exception_halted:
    db "[ PANIC ] CPU EXECUTION HALTED", 0