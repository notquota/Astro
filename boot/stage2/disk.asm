
bits 16

%define DISK_RETRIES 3

disk_load_test:
    pusha
    push es

    xor ax, ax
    mov es, ax

    mov bx, DATA_ADDR
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, DATA_SECTOR
    mov dh, 0
    mov dl, [boot_drive]

    int 0x13
    jc .failed

    cmp al, 1
    jne .failed

    clc
    jmp .done

.failed:
    stc

.done:
    pop es
    popa
    ret

disk_load_kernel:
    pusha
    push es

    mov ah, 0x08
    mov dl, [boot_drive]
    int 0x13
    jc .failed

    mov al, cl
    and al, 0x3F
    xor ah, ah

    test ax, ax
    jz .failed

    mov [disk_sectors_per_track], ax

    xor ax, ax
    mov al, dh
    inc ax

    mov [disk_heads], ax

    mov ax, [disk_sectors_per_track]
    mul word [disk_heads]

    test dx, dx
    jnz .failed

    test ax, ax
    jz .failed

    mov [disk_sectors_per_cylinder], ax

    mov word [disk_kernel_lba], KERNEL_LBA
    mov word [disk_kernel_remaining], KERNEL_SECTOR_COUNT
    mov word [disk_kernel_segment], KERNEL_LOAD_SEGMENT

.next_sector:
    cmp word [disk_kernel_remaining], 0
    je .success

    mov ax, [disk_kernel_lba]
    xor dx, dx

    div word [disk_sectors_per_cylinder]

    cmp ax, 1023
    ja .failed

    mov [disk_cylinder], ax

    mov ax, dx
    xor dx, dx

    div word [disk_sectors_per_track]

    cmp ax, 255
    ja .failed

    mov [disk_head], al

    mov ax, dx
    inc ax

    mov [disk_sector], al

    mov ax, [disk_cylinder]

    mov ch, al
    mov cl, [disk_sector]

    mov al, ah
    and al, 0x03
    shl al, 6
    or cl, al

    mov [disk_ch], ch
    mov [disk_cl], cl

    mov byte [disk_retries_left], DISK_RETRIES

.retry:
    mov ax, [disk_kernel_segment]
    mov es, ax

    xor bx, bx

    mov ah, 0x02
    mov al, 1

    mov ch, [disk_ch]
    mov cl, [disk_cl]
    mov dh, [disk_head]
    mov dl, [boot_drive]

    int 0x13
    jc .reset

    cmp al, 1
    jne .reset

    add word [disk_kernel_segment], 0x20
    inc word [disk_kernel_lba]
    dec word [disk_kernel_remaining]

    jmp .next_sector

.reset:
    xor ah, ah
    mov dl, [boot_drive]

    int 0x13

    dec byte [disk_retries_left]
    jnz .retry

.failed:
    stc
    jmp .done

.success:
    clc

.done:
    pop es
    popa
    ret

disk_verify_kernel:
    push ax
    push cx
    push si
    push di
    push es

    mov ax, KERNEL_LOAD_SEGMENT
    mov es, ax

    xor di, di
    mov si, kernel_signature
    mov cx, KERNEL_SIGNATURE_SIZE

.compare:
    mov al, [es:di]
    cmp al, [si]
    jne .failed

    inc di
    inc si

    loop .compare

    clc
    jmp .done

.failed:
    stc

.done:
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

disk_sectors_per_track:
    dw 0

disk_heads:
    dw 0

disk_sectors_per_cylinder:
    dw 0

disk_cylinder:
    dw 0

disk_head:
    db 0

disk_sector:
    db 0

disk_ch:
    db 0

disk_cl:
    db 0

disk_retries_left:
    db 0

disk_kernel_lba:
    dw 0

disk_kernel_remaining:
    dw 0

disk_kernel_segment:
    dw 0

kernel_signature:
    db "A5TR0KRN"