
bits 64

kernel_runtime_initialize:
    cli
    cld

    call kernel_status_initialize
    call cpu_interrupts_initialize

    call cpu_gdt_initialize

    mov rdi, KSTATUS_GDT
    call kernel_status_mark

    call cpu_idt_initialize

    mov rdi, KSTATUS_IDT
    call kernel_status_mark

    call debug_diagnostics_run
    test eax, eax
    jz .failed

    mov rdi, KSTATUS_CPU
    call kernel_status_mark

    clc
    ret

.failed:
    stc
    ret

kernel_runtime_failure:
    cli

    call kernel_console_clear

    mov rdi, 2
    mov rsi, kernel_runtime_error
    mov bl, 0x0C
    call debug_console_line

    jmp kernel_halt

kernel_runtime_error:
    db "[ PANIC ] CPU RUNTIME INITIALIZATION FAILED", 0