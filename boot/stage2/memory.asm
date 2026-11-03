bits 16

memory_detect:
    pushad
    push es

    xor ax, ax
    mov es, ax

    mov word [memory_count], 0
    mov word [memory_usable_count], 0

    mov di, E820_BUFFER
    xor ebx, ebx

.next:
    cmp word [memory_count], E820_MAX_ENTRIES
    jae .failed

    mov dword [es:di + 20], 1

    mov eax, 0xE820
    mov edx, E820_SIGNATURE
    mov ecx, E820_ENTRY_SIZE

    int 0x15
    jc .carry

    cmp eax, E820_SIGNATURE
    jne .failed

    cmp ecx, 20
    jb .failed

    cmp ecx, E820_ENTRY_SIZE
    ja .failed

    cmp ecx, 20
    jne .check

    mov dword [es:di + 20], 1

.check:
    mov eax, [es:di + 8]
    or eax, [es:di + 12]
    jz .continue

    cmp ecx, E820_ENTRY_SIZE
    jne .store

    test dword [es:di + 20], 1
    jz .continue

.store:
    inc word [memory_count]

    cmp dword [es:di + 16], E820_TYPE_USABLE
    jne .advance

    inc word [memory_usable_count]

.advance:
    add di, E820_ENTRY_SIZE

.continue:
    test ebx, ebx
    jnz .next

    cmp word [memory_count], 0
    je .failed

    clc
    jmp .done

.carry:
    cmp word [memory_count], 0
    je .failed

    test ebx, ebx
    jnz .failed

    clc
    jmp .done

.failed:
    stc

.done:
    pop es
    popad
    ret

memory_print_map:
    pushad
    push es

    xor ax, ax
    mov es, ax

    mov si, memory_header
    call video_print

    mov bx, E820_BUFFER
    mov bp, [memory_count]

.next:
    test bp, bp
    jz .done

    mov eax, [es:bx]
    mov edx, [es:bx + 4]
    call video_hex64

    mov si, memory_separator
    call video_print

    mov eax, [es:bx + 8]
    mov edx, [es:bx + 12]
    call video_hex64

    mov si, memory_separator
    call video_print

    mov eax, [es:bx + 16]
    call video_hex32

    mov si, memory_newline
    call video_print

    add bx, E820_ENTRY_SIZE
    dec bp
    jmp .next

.done:
    pop es
    popad
    ret

memory_count dw 0
memory_usable_count dw 0

memory_header:
    db 10
    db "BASE              LENGTH            TYPE", 10
    db "------------------------------------------------", 10, 0

memory_separator db "  ", 0
memory_newline db 10, 0