
bits 64

kernel_panic_boot:
    call kernel_console_clear

    mov rdi, VGA_BASE + 320
    mov rsi, kernel_panic_message
    mov bl, 0x0C

    call kernel_console_write

    jmp kernel_halt

kernel_panic_message:
    db "[ PANIC ] INVALID BOOT INFORMATION", 0
