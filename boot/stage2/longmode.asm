
bits 64

%define VGA_BASE 0xB8000
%define BOOT_STACK_TOP 0x70000

long_entry:
    cli
    cld

    mov ax, GDT_DATA_SELECTOR
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov rsp, BOOT_STACK_TOP
    mov rbp, rsp

    call lm_verify_kernel
    jc lm_kernel_failure

    call lm_prepare_boot_info

    mov rdi, BOOT_INFO_ADDRESS
    mov rax, KERNEL_ENTRY_ADDRESS

    jmp rax

lm_verify_kernel:
    push rax
    push rcx
    push rsi
    push rdi

    mov rsi, kernel_signature
    mov rdi, KERNEL_LOAD_ADDRESS
    mov ecx, KERNEL_SIGNATURE_SIZE

.compare:
    mov al, [rsi]
    cmp al, [rdi]
    jne .failed

    inc rsi
    inc rdi

    dec ecx
    jnz .compare

    clc
    jmp .done

.failed:
    stc

.done:
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

lm_prepare_boot_info:
    mov rdi, BOOT_INFO_ADDRESS

    mov rax, BOOT_INFO_MAGIC
    mov [rdi], rax

    mov qword [rdi + 8], KERNEL_LOAD_ADDRESS
    mov qword [rdi + 16], KERNEL_ENTRY_ADDRESS
    mov qword [rdi + 24], 0x5000

    ret

lm_kernel_failure:
    mov word [VGA_BASE], 0x0C46
    mov word [VGA_BASE + 2], 0x0C41
    mov word [VGA_BASE + 4], 0x0C49
    mov word [VGA_BASE + 6], 0x0C4C

lm_halt:
    cli

.loop:
    hlt
    jmp .loop
