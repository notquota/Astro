bits 16

a20_enable:
    call a20_check
    jnc .success

    mov ax, 0x2401
    int 0x15

    call a20_check
    jnc .success

    in al, 0x92
    test al, 0x02
    jnz .verify

    or al, 0x02
    and al, 0xFE
    out 0x92, al

.verify:
    call a20_check
    ret

.success:
    clc
    ret

a20_check:
    pushf
    cli

    push ax
    push bx
    push ds
    push es
    push si
    push di

    xor ax, ax
    mov ds, ax

    mov ax, 0xFFFF
    mov es, ax

    mov si, 0x0600
    mov di, 0x0610

    mov al, [ds:si]
    mov bl, [es:di]

    mov ah, al
    not ah

    mov [ds:si], ah

    cmp [es:di], ah
    je .disabled

    mov byte [a20_result], 1
    jmp .restore

.disabled:
    mov byte [a20_result], 0

.restore:
    mov [ds:si], al
    mov [es:di], bl

    pop di
    pop si
    pop es
    pop ds
    pop bx
    pop ax

    popf

    cmp byte [a20_result], 1
    jne .failed

    clc
    ret

.failed:
    stc
    ret

a20_result db 0