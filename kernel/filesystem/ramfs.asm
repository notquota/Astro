bits 64

%define FS_MAX_ENTRIES 16
%define FS_ENTRY_SIZE 32
%define FS_DATA_SIZE 128
%define FS_TYPE_DIR 1
%define FS_TYPE_FILE 2

fs_initialize:
    mov byte [fs_cwd], 0

    lea rdi, [fs_entries]
    xor eax, eax
    mov ecx, FS_MAX_ENTRIES * FS_ENTRY_SIZE / 8
    rep stosq

    lea rdi, [fs_data]
    mov ecx, FS_MAX_ENTRIES * FS_DATA_SIZE / 8
    rep stosq

    ret

fs_lookup:
    push rbx
    push r12
    push r13

    mov r13, rdi
    xor r12d, r12d

.search:
    cmp r12d, FS_MAX_ENTRIES
    jae .missing

    mov rax, r12
    shl rax, 5
    lea rbx, [fs_entries + rax]

    cmp byte [rbx], 1
    jne .next

    mov al, [fs_cwd]
    cmp [rbx + 2], al
    jne .next

    mov rdi, r13
    lea rsi, [rbx + 4]
    call fs_equal

    test eax, eax
    jnz .found

.next:
    inc r12
    jmp .search

.found:
    lea rax, [r12 + 1]
    jmp .done

.missing:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

fs_equal:
.compare:
    mov al, [rdi]
    cmp al, [rsi]
    jne .different

    test al, al
    jz .equal

    inc rdi
    inc rsi
    jmp .compare

.equal:
    mov eax, 1
    ret

.different:
    xor eax, eax
    ret

fs_create:
    push rbx
    push r12
    push r13
    push r14

    mov r13, rdi
    mov r14, rsi

    xor ecx, ecx

.validate:
    mov al, [r13 + rcx]
    test al, al
    jz .valid

    cmp al, '/'
    je .failed

    cmp al, ' '
    je .failed

    inc ecx
    cmp ecx, 23
    ja .failed

    jmp .validate

.valid:
    test ecx, ecx
    jz .failed

    cmp r14, FS_TYPE_DIR
    je .type_ok

    cmp r14, FS_TYPE_FILE
    jne .failed

.type_ok:
    mov rdi, r13
    call fs_lookup

    test rax, rax
    jnz .failed

    xor r12d, r12d

.search:
    cmp r12d, FS_MAX_ENTRIES
    jae .failed

    mov rax, r12
    shl rax, 5
    lea rbx, [fs_entries + rax]

    cmp byte [rbx], 0
    je .found

    inc r12
    jmp .search

.found:
    mov byte [rbx], 1
    mov [rbx + 1], r14b

    mov al, [fs_cwd]
    mov [rbx + 2], al

    mov byte [rbx + 3], 0

    lea rdi, [rbx + 4]
    mov rsi, r13

.copy:
    lodsb
    stosb

    test al, al
    jnz .copy

    lea rax, [r12 + 1]
    jmp .done

.failed:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

fs_get:
    test rdi, rdi
    jz .failed

    cmp rdi, FS_MAX_ENTRIES
    ja .failed

    lea rax, [rdi - 1]
    shl rax, 5
    lea rax, [fs_entries + rax]

    cmp byte [rax], 1
    jne .failed

    ret

.failed:
    xor eax, eax
    ret

fs_change_dir:
    push rbx

    mov rbx, rdi
    call fs_get

    test rax, rax
    jz .failed

    cmp byte [rax + 1], FS_TYPE_DIR
    jne .failed

    mov [fs_cwd], bl
    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop rbx
    ret

fs_write:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi

    call fs_get

    test rax, rax
    jz .failed

    cmp byte [rax + 1], FS_TYPE_FILE
    jne .failed

    mov rbx, rax

    mov rax, r12
    dec rax
    shl rax, 7
    lea rdi, [fs_data + rax]

    xor ecx, ecx

.copy:
    cmp ecx, FS_DATA_SIZE - 1
    jae .finish

    mov al, [r13 + rcx]
    test al, al
    jz .finish

    mov [rdi + rcx], al

    inc ecx
    jmp .copy

.finish:
    mov byte [rdi + rcx], 0
    mov [rbx + 3], cl

    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

fs_read:
    push rbx

    mov rbx, rdi
    call fs_get

    test rax, rax
    jz .failed

    cmp byte [rax + 1], FS_TYPE_FILE
    jne .failed

    lea rax, [rbx - 1]
    shl rax, 7
    lea rax, [fs_data + rax]

    jmp .done

.failed:
    xor eax, eax

.done:
    pop rbx
    ret

fs_cwd:
    db 0

align 16

fs_entries:
    times FS_MAX_ENTRIES * FS_ENTRY_SIZE db 0

align 16

fs_data:
    times FS_MAX_ENTRIES * FS_DATA_SIZE db 0