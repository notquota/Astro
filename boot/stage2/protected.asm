bits 32

%define PM_STACK_TOP 0x70000

%define PML4_ADDRESS 0x10000
%define PDPT_ADDRESS 0x11000
%define PD_ADDRESS   0x12000

protected_entry:
    cli

    mov ax, GDT_DATA_SELECTOR
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, PM_STACK_TOP
    mov ebp, esp

    cld

    mov esi, pm_message
    call pm_print

    call pm_check_longmode
    jc pm_unsupported

    mov esi, pm_cpu_ok
    call pm_print

    call pm_setup_paging

    mov esi, pm_paging_ok
    call pm_print

    mov esi, pm_transition
    call pm_print

    jmp pm_enter_longmode

pm_check_longmode:
    pushad

    mov eax, 0x00000001
    cpuid

    test edx, 1 << 3
    jz .failed

    test edx, 1 << 5
    jz .failed

    test edx, 1 << 6
    jz .failed

    mov eax, 0x80000000
    cpuid

    cmp eax, 0x80000001
    jb .failed

    mov eax, 0x80000001
    cpuid

    test edx, 1 << 29
    jz .failed

    popad
    clc
    ret

.failed:
    popad
    stc
    ret

pm_setup_paging:
    pushad

    mov edi, PML4_ADDRESS
    xor eax, eax
    mov ecx, (4096 * 3) / 4
    rep stosd

    mov dword [PML4_ADDRESS], PDPT_ADDRESS | 0x03
    mov dword [PML4_ADDRESS + 4], 0

    mov dword [PDPT_ADDRESS], PD_ADDRESS | 0x03
    mov dword [PDPT_ADDRESS + 4], 0

    mov dword [PD_ADDRESS], 0x00000083
    mov dword [PD_ADDRESS + 4], 0

    popad
    ret

pm_enter_longmode:
    cli

    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    mov eax, PML4_ADDRESS
    mov cr3, eax

    mov ecx, 0xC0000080
    rdmsr

    or eax, 1 << 8
    wrmsr

    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    jmp dword GDT_LONG_CODE_SELECTOR:long_entry

pm_unsupported:
    mov esi, pm_error
    call pm_print

pm_halt:
    cli

.loop:
    hlt
    jmp .loop

pm_print:
    pushad

    mov edi, [pm_cursor]

.next:
    lodsb
    test al, al
    jz .done

    cmp al, 10
    je .newline

    cmp edi, 2000
    jae .done

    mov ah, 0x07
    mov [0xB8000 + edi * 2], ax

    inc edi
    jmp .next

.newline:
    mov eax, edi
    xor edx, edx
    mov ebx, 80
    div ebx
    inc eax
    imul eax, 80
    mov edi, eax

    jmp .next

.done:
    mov [pm_cursor], edi

    popad
    ret

pm_cursor dd 0

pm_message:
    db "[ BOOT ] 32-bit protected mode active", 10, 0

pm_cpu_ok:
    db "[  OK  ] CPU supports x86-64 and 2 MiB pages", 10, 0

pm_paging_ok:
    db "[  OK  ] initial page tables constructed", 10, 0

pm_transition:
    db "[ BOOT ] entering 64-bit long mode", 10, 0

pm_error:
    db "[ FAIL ] CPU lacks required long-mode features", 10, 0