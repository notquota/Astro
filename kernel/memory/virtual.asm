bits 64

memory_virtual_translate:
    push rbx
    push r12

    mov r8, rdi

    mov r12, 0x000FFFFFFFFFF000

    mov rax, cr3
    and rax, r12

    mov rcx, r8
    shr rcx, 39
    and ecx, 511

    mov rax, [rax + rcx * 8]
    test al, 1
    jz .failed

    and rax, r12

    mov rcx, r8
    shr rcx, 30
    and ecx, 511

    mov rax, [rax + rcx * 8]
    test al, 1
    jz .failed

    test al, 0x80
    jnz .page1g

    and rax, r12

    mov rcx, r8
    shr rcx, 21
    and ecx, 511

    mov rax, [rax + rcx * 8]
    test al, 1
    jz .failed

    test al, 0x80
    jnz .page2m

    and rax, r12

    mov rcx, r8
    shr rcx, 12
    and ecx, 511

    mov rax, [rax + rcx * 8]
    test al, 1
    jz .failed

    and rax, r12

    mov rcx, r8
    and ecx, 0xFFF
    or rax, rcx

    jmp .done

.page2m:
    mov rbx, 0x000FFFFFFFE00000
    and rax, rbx

    mov rcx, r8
    and ecx, 0x1FFFFF
    or rax, rcx

    jmp .done

.page1g:
    mov rbx, 0x000FFFFFC0000000
    and rax, rbx

    mov rcx, r8
    and ecx, 0x3FFFFFFF
    or rax, rcx

    jmp .done

.failed:
    mov rax, -1

.done:
    pop r12
    pop rbx
    ret