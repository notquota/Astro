bits 64

kernel_main:
    call kernel_subsystems_initialize

    mov rdi, KSTATUS_SUBSYSTEMS
    call kernel_status_mark

    call kernel_console_clear

    mov rdi, 1
    mov rsi, kernel_title
    mov bl, 0x0B
    call debug_console_line

    mov rdi, 3
    mov rsi, kernel_status
    mov bl, 0x0A
    call debug_console_line

    mov rdi, 4
    mov rsi, kernel_boot_status
    mov bl, 0x0A
    call debug_console_line

    mov rdi, 5
    mov rsi, kernel_cpu_status
    mov bl, 0x0A
    call debug_console_line

    mov rdi, 6
    mov rsi, kernel_idt_status
    mov bl, 0x0A
    call debug_console_line

    mov rdi, 7
    mov rsi, kernel_core_status
    mov bl, 0x0A
    call debug_console_line

    mov rdi, 9
    mov rsi, kernel_test_start
    mov bl, 0x0B
    call debug_console_line

    call kernel_selftest_run

    mov rdi, 11
    mov rsi, kernel_test_passed
    mov bl, 0x0A
    call debug_console_line

    mov rax, [selftest_passed]
    mov rdi, VGA_BASE + 11 * 160 + 22 * 2
    mov bl, 0x0A
    call debug_console_hex64

    mov rdi, 12
    mov rsi, kernel_test_failed
    mov bl, 0x0C
    call debug_console_line

    mov rax, [selftest_failed]
    mov rdi, VGA_BASE + 12 * 160 + 22 * 2
    mov bl, 0x0C
    call debug_console_hex64

    cmp qword [selftest_failed], 0
    jne .failed

    mov rdi, 14
    mov rsi, kernel_ready
    mov bl, 0x0A
    call debug_console_line

    call kernel_wait_three_seconds

    call shell_initialize
    jmp shell_run

.failed:
    mov rdi, 14
    mov rsi, kernel_test_failure
    mov bl, 0x0C
    call debug_console_line

    jmp kernel_halt

kernel_title:
    db "A5TR0 / KERNEL", 0

kernel_status:
    db "[  OK  ] KERNEL INITIALIZED", 0

kernel_boot_status:
    db "[  OK  ] BOOT PROTOCOL VALIDATED", 0

kernel_cpu_status:
    db "[  OK  ] CPU STATE VERIFIED", 0

kernel_idt_status:
    db "[  OK  ] KERNEL GDT AND IDT INSTALLED", 0

kernel_core_status:
    db "[  OK  ] CORE SUBSYSTEMS INITIALIZED", 0

kernel_test_start:
    db "[ TEST ] RUNNING CORE SELF-TESTS", 0

kernel_test_passed:
    db "TESTS PASSED:", 0

kernel_test_failed:
    db "TESTS FAILED:", 0

kernel_ready:
    db "[  OK  ] ALL CORE TESTS PASSED", 0

kernel_test_failure:
    db "[ FAIL ] CORE SELF-TEST FAILURE", 0